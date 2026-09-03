# Platform Cost Reduction: Recommendations

**Status:** Recommendations for planning  
**Owner:** Platform  
**Scope:** **Overall AWS / platform spend** — not chatbot-only. Covers CHT Platform (prod + future dev + DR), MediaHub EC2, future `cht-companion`, Content Hub touchpoints, networking (NAT), databases, LLM, and idle non-prod capacity.  
**Related:** [chmbot-migration-architecture.md](./chmbot-migration-architecture.md), [staging-teardown.md](../runbooks/staging-teardown.md), [CHM-Platform-Roadmap-Plan.md](../reports/CHM-Platform-Roadmap-Plan.md), [multi-region-active-passive-us-east-2.md](../runbooks/multi-region-active-passive-us-east-2.md)

Chatbot choices (Service Connect, pgvector, separate repo) appear here only as **one slice** of the broader cost program. MediaHub EC2 retirement, NAT, and **dev lightswitch** are the larger dollars.

---



## 1. Executive recommendations (TL;DR)


| Priority | Action                                                                                                                            | Est. monthly impact                                                     | Effort                   |
| -------- | --------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | ------------------------ |
| **P0**   | **Fully decommission MediaHub EC2** (after catalog/chat ownership is clear)                                                       | **Largest** (often hundreds $/mo: instance + EBS + EIP + idle GPU risk) | Med–high (cutover first) |
| **P0**   | Do **not** rebuild MediaHub as always-on multi-service Fargate + Multi-AZ RDS if Hub is being retired                             | Avoids **+$100–200**/mo locked in by roadmap Phase 4                    | Decision                 |
| **P1**   | **Dev “lightswitch”**: scale ECS desired → 0 + stop/start or snapshot-hibernate pattern for RDS off-hours                         | Save **~40–70%** of AWS **dev** bill                                    | Low–med                  |
| **P1**   | **Single NAT Gateway** in non-prod (and prod if HA not required on NAT)                                                           | Save **~$32+/mo per extra NAT**                                         | Low                      |
| **P1**   | Keep **cht-companion** in a **separate repo**; **Fargate Q&A on existing cluster** + **Lambda KB**; no public ALB; small `cht-companion-db` | Keeps chat add-on small vs OpenSearch/EC2/new cluster                   | Med                      |
| **P2**   | Right-size prod Fargate / RDS; avoid Aurora Global / large DR warm standby unless RTO demands it                                  | Tens–hundreds $/mo                                                      | Med                      |
| **P2**   | LLM budgets (Bedrock) + members-only chat                                                                                         | Variable but material                                                   | Low                      |
| **P3**   | Schedule-based DR: warm standby at 0 or cold restore drills                                                                       | Save warm us-east-2 compute                                             | Med                      |


**Do not** use EC2 Auto Scaling Groups as the primary cost lever for CHT app tiers—you are already on **Fargate**. ASG helps only if you still run EC2 (MediaHub today, or GPU render). For ECS/RDS, use **desired count schedules** and **instance stop/start** (a “lightswitch”).

---



## 2. Repo ownership (CHT Companion)

**Recommendation:** Product name **CHT Companion**; GitHub repo **`cht-companion`** lives in a **separate repository** from:

- `cht-platform-tool` (CHT web + NestJS + workers)
- Content Hub


| Concern                       | Guidance                                                                                             |
| ----------------------------- | ---------------------------------------------------------------------------------------------------- |
| Why separate                  | Independent release cadence, smaller blast radius, clearer cost attribution (ECR/ECS tagged to chat) |
| What stays in CHT platform    | NestJS **BFF** `/api/chat/`*, React UI, Service Connect client config, shared Cognito                |
| What lives in `cht-companion` repo | RAG API, KB worker, embeddings pipeline, chat Terraform (or chat module consumed by platform env)    |
| Contract                      | OpenAPI for chat; CHT only talks over **Service Connect**                                            |


Platform Terraform can still **deploy** the chat services into the same ECS cluster; separation is about **code ownership**, not necessarily a second AWS account.

---



## 3. Biggest lever: decommission MediaHub EC2



### Why it dominates cost

Typical MediaHub-on-EC2 bill includes:

- 24/7 EC2 (often oversized for Compose: API + Postgres + Redis + chatbot + workers)
- EBS volumes (and snapshots)
- Possible Elastic IP / public bandwidth
- Ops time (patching, disk full, manual deploys)—soft cost

**Recommendation:** Treat **EC2 retirement** as a cost program, not only an architecture program.

### Two paths (pick one; do not do both)


| Path                                            | Meaning                                                                                                                                                    | Cost outcome                                                                        |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| **A. Retire Hub (preferred if product agrees)** | Move must-keep capabilities into CHT / Content Hub / `cht-companion`; turn off EC2; **do not** stand up full `mediahub-api`×2 + worker + reports + Multi-AZ RDS | **Max savings**                                                                     |
| **B. Replace Hub on ECS**                       | Per older Phase 4 plan: Fargate + RDS + Redis                                                                                                              | **Moves** cost off EC2 onto managed services; may not save much unless EC2 was huge |


Roadmap cost table already estimated MediaHub on ECS at roughly **+$140–170/mo** (RDS + Fargate + Redis) **before** LLM. If the goal is savings, **Path A** beats Path B.

### Cutover order for Path A (cost-aware)

1. **Chat** → `cht-companion` + `cht-companion-db` (separate repo; Service Connect).
2. **Catalog** → Content Hub / CHT-owned public API (or freeze read-only snapshot period).
3. **Admin Hub UI** → only if still required; otherwise archive.
4. **Stop EC2** → snapshot disks → terminate → release EIPs.
5. Cancel unused domains / certs for Hub-only hosts when traffic is gone.

---



## 4. Dev / non-prod “lightswitch” (ECS + RDS)

Staging was already torn down ([staging-teardown.md](../runbooks/staging-teardown.md)). When **Phase 3 AWS dev** exists (or any always-on non-prod), idle 24/7 stacks waste money.

### What “lightswitch” means


| Resource                                           | Off                                                         | On                         |
| -------------------------------------------------- | ----------------------------------------------------------- | -------------------------- |
| **ECS services** (`backend`, `worker`, `cht-companion`) | `desiredCount = 0`                                          | Restore normal desired (1) |
| **RDS / Aurora**                                   | `stop` instance (or use tiny class + stop)                  | `start`                    |
| **ALB**                                            | Leave up (cheap vs rebuild) **or** destroy in long holidays | —                          |
| **NAT**                                            | Hard to toggle safely; prefer **1 NAT** in dev always       | —                          |
| **ElastiCache**                                    | No stop API → scale to smallest or delete in long idle      | Recreate if deleted        |


**RDS note:** You can typically leave an instance **stopped up to 7 days**, then AWS may auto-restart. For longer “off,” take a snapshot and delete the instance (restore when needed)—true cold lightswitch.

### Recommended mechanism (not ASG)


| Approach                                                                                       | Use when                                                 |
| ---------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| **EventBridge Scheduler → Lambda / Step Functions** calling ECS UpdateService + RDS Stop/Start | Best default “lightswitch”                               |
| **GitHub Action** `workflow_dispatch` **+ cron** (`dev-up` / `dev-down`)                       | Simple; team-controlled                                  |
| **ECS Service Auto Scaling to 0 on schedule**                                                  | Good for Fargate API/worker                              |
| **EC2 ASG scheduled actions**                                                                  | Only for remaining EC2 (MediaHub until gone; GPU render) |


**Recommended schedule (US East business hours example):**

- **Up:** Mon–Fri 08:00 America/New_York  
- **Down:** Mon–Fri 20:00 + all weekend

Expect **~60%+** savings on Fargate + RDS compute for that env (ALB/NAT remain).

### Dev sizing defaults (when “on”)


| Service                  | Recommendation                                                   |
| ------------------------ | ---------------------------------------------------------------- |
| ECS backend / worker     | `desired = 1`, smallest sensible CPU/mem                         |
| `cht-companion`               | `desired = 0` when idle; `1` when testing chat                   |
| `cht-companion-kb`            | Never always-on; invoke on demand                                |
| RDS                      | `db.t4g.micro` or `small`, **Single-AZ**, short backup retention |
| NAT                      | **One** NAT Gateway for the VPC                                  |
| Multi-AZ / Aurora Global | **Never** in dev                                                 |




### Prod vs lightswitch


| Env              | Lightswitch                                                   |
| ---------------- | ------------------------------------------------------------- |
| **Prod**         | No (or only scale workers overnight if queues allow)          |
| **DR us-east-2** | Prefer **desired 0** + scale-up runbook, not 50% warm forever |
| **Dev**          | **Yes** — default recommendation                              |


---



## 5. Architecture changes that save money



### Keep


| Pattern                             | Why it saves                          |
| ----------------------------------- | ------------------------------------- |
| **Fargate** for APIs                | No idle EC2 fleet for app tiers       |
| **Service Connect-only** `cht-companion` | No extra public ALB for chat          |
| **pgvector on small RDS**           | Avoid OpenSearch Serverless OCU floor |
| **SQS + on-demand workers**         | Pay when jobs run                     |
| **CloudFront + S3** for frontend    | Cheap static hosting                  |
| **One Redis per env** (if needed)   | Already noted in cache contract       |




### Change / avoid


| Anti-pattern                                              | Recommendation                                             |
| --------------------------------------------------------- | ---------------------------------------------------------- |
| MediaHub monolith EC2                                     | Decommission (Path A)                                      |
| Always-on reports/LLM containers                          | Batch / queue; scale to 0                                  |
| OpenSearch Serverless for chat v1                         | Use pgvector                                               |
| Aurora Global + large DR warm ECS “just in case”          | Cold DR or desired-0 standby unless compliance forces warm |
| NAT per AZ in **dev**                                     | Single NAT                                                 |
| Multi-AZ RDS in **dev**                                   | Single-AZ                                                  |
| Anonymous public LLM                                      | Members-only (chat doc)                                    |
| Duplicate always-on stacks (old staging + prod + warm DR) | One prod + lightswitched dev                               |




### Optional: Fargate Spot

Use **Fargate Spot** for `cht-companion-kb` and non-critical workers (interruptible). Keep `cht-companion` request path on regular Fargate.

---



## 6. Networking & data transfer


| Item             | Recommendation                                                                    |
| ---------------- | --------------------------------------------------------------------------------- |
| NAT Gateway      | **1× in dev**; in prod prefer 1 unless AZ-level NAT HA is required                |
| Cross-AZ chatter | Keep chat + `cht-companion-db` in same AZ placement strategy when Single-AZ DB         |
| Egress to LLM    | Bedrock in-region reduces some internet gateway patterns; still monitor NAT bytes |
| CloudFront       | Cache static assets aggressively; APIs via `/api*` without cache                  |


NAT is often a **top-3** silent cost after compute and RDS.

---



## 7. RDS / Aurora cost hygiene


| Env           | Recommendation                                                                   |
| ------------- | -------------------------------------------------------------------------------- |
| Dev           | Smallest class that runs migrations; Single-AZ; lightswitch stop/start           |
| Prod CHT      | Right-size after CloudWatch CPU/mem (don’t jump to `r6g.large` without evidence) |
| `cht-companion-db` | Separate **small** instance; Single-AZ until chat is critical path               |
| MediaHub RDS  | **Don’t create** if Path A (retire Hub)                                          |
| Backups       | Shorter retention in non-prod; snapshot before destroy                           |


**Aurora Global** improves DR but **raises** fixed DB cost—pair with an honest RTO requirement, not default enablement.

---



## 8. ECS cost hygiene


| Lever         | Recommendation                                                                                                        |
| ------------- | --------------------------------------------------------------------------------------------------------------------- |
| Desired count | Prod: minimum that meets SLO (often 2 backend for deploy safety; 1 worker if queue latency OK)                        |
| Autoscale     | Scale **out on CPU/ALB/SQS**; scale **in aggressively** in non-prod                                                   |
| Deploy config | Avoid locking `desired=1` with 100% max surge deadlocks (already noted in worker module)—use efficient rolling params |
| Chat          | `cht-companion` desired 1–2 prod; 0 when lightswitch off in dev                                                            |
| Cluster       | Prefer **one ECS cluster per env**; many services, shared ALB where possible                                          |


ASG is **not** the primary tool here unless you still operate EC2.

---



## 9. Suggested automation: `dev-lightswitch`

**Build a small, boring control plane:**

1. **EventBridge Scheduler** rules: `cht-dev-up`, `cht-dev-down`.
2. Lambda (Python) actions:
  - ECS: `UpdateService` desiredCount for `backend`, `worker`, `cht-companion`  
  - RDS: `StopDBInstance` / `StartDBInstance` for `cht-dev-db` (+ `cht-companion-db` if present)
3. Slack/email notify on failure.
4. Manual override: GitHub Action `workflow_dispatch` for “need env at Saturday.”
5. Tag all resources `Environment=dev`, `Lightswitch=true` for cost reports.

**Guardrails:**

- Never target prod cluster/account by tag mistake (separate AWS account or hard-coded allowlist).  
- Health check after “up” before notifying “ready.”  
- Document that stopped RDS may auto-restart after 7 days.

---



## 10. Cost visibility


| Practice            | Recommendation                                                                                          |
| ------------------- | ------------------------------------------------------------------------------------------------------- |
| Tagging             | `Project`, `Environment`, `Service` (`cht-platform`, `cht-companion`, `mediahub`) on all Terraform resources |
| CUR + Cost Explorer | Monthly review; filter by tag                                                                           |
| Budgets             | AWS Budget alerts: total, Bedrock, NAT                                                                  |
| Before/after        | Snapshot MediaHub EC2 monthly cost **before** terminate; compare 30 days after                          |


Without tags, chat/Hub savings are hard to prove.

---



## 11. Phased cost program



### Phase C0 — Quick wins (1–2 weeks)

- [ ] Confirm MediaHub EC2 instance class, EBS, EIP, monthly Cost Explorer line items  
- [ ] Prod: audit NAT count; collapse to 1 if safe  
- [ ] Prod: verify ECS desired counts aren’t over-provisioned  
- [ ] Disable unused warm DR capacity (desired 0) if not required  
- [ ] Bedrock/LLM budget alarm  



### Phase C1 — Lightswitch (2–3 weeks)

- [ ] Implement `dev-up` / `dev-down` automation  
- [ ] Schedule business-hours only for AWS dev  
- [ ] Document manual override  



### Phase C2 — MediaHub EC2 off (aligned with product)

- [ ] Decide Path A (retire) vs Path B (ECS rebuild)  
- [ ] If Path A: finish `cht-companion` + catalog ownership → terminate EC2  
- [ ] If Path B: size Hub Fargate **smaller** than current EC2; Single-AZ RDS until needed  



### Phase C3 — Chat cost envelope

- [ ] Separate repo `cht-companion`  
- [ ] Service Connect only; pgvector; on-demand KB  
- [ ] Members-only chat; token budgets  

---



## 12. What not to do

- Don’t add **EKS** “for cost”—control plane usually costs more at this scale.  
- Don’t put vectors on **prod CHT Aurora** to “save a DB”—risk ≠ savings.  
- Don’t keep MediaHub EC2 “for a few admin tools” without measuring; idle EC2 is expensive.  
- Don’t lightswitch **prod** RDS without a hardened runbook and customer comms.  
- Don’t assume ASG alone fixes Fargate bills—**desired count and schedule** do.

---



## 13. Success metrics


| Metric          | Target                                                 |
| --------------- | ------------------------------------------------------ |
| MediaHub EC2    | $0 after Path A complete                               |
| AWS dev monthly | ≥ **50%** reduction vs 24/7 baseline after lightswitch |
| NAT (non-prod)  | Exactly **1** gateway                                  |
| Chat add-on     | No OpenSearch Serverless; no public chat ALB           |
| Tag coverage    | ≥ 95% of monthly spend attributable by `Service`       |


---



## 14. Related documents


| Doc                                                                                              | Relevance                                       |
| ------------------------------------------------------------------------------------------------ | ----------------------------------------------- |
| [chmbot-migration-architecture.md](./chmbot-migration-architecture.md)                           | `cht-companion` architecture; Bedrock; pgvector      |
| [staging-teardown.md](../runbooks/staging-teardown.md)                                           | Already realized staging savings                |
| [CHM-Platform-Roadmap-Plan.md](../reports/CHM-Platform-Roadmap-Plan.md)                          | Phase 4 Hub cost estimates to avoid if retiring |
| [multi-region-active-passive-us-east-2.md](../runbooks/multi-region-active-passive-us-east-2.md) | DR warm vs cold tradeoff                        |
| [aurora-global-platform-migration.md](../runbooks/aurora-global-platform-migration.md)           | Higher DB cost for DR                           |


