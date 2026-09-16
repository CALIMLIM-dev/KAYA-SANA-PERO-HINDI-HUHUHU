# Appendix: Data Flow Diagrams

Level 0 (context), Level 1 (the twelve processes), Level 2 for each process, and Level 3 for the three decisions that carry the most rules. Drawn in plain text so they can be pasted anywhere.

```
┌──────────┐        ╭──────────────╮        ┌────┬──────────┐
│  ENTITY  │        │  n.0  Process│        │ Dn │  store   │
└──────────┘        ╰──────────────╯        └────┴──────────┘

────▶  data flow
```

---

## Level 0 — Context

```
                            ┌──────────────┐
                            │    ADMIN     │
                            └──────┬───▲───┘
                             ruling│   │queue
                                   ▼   │
┌──────────┐                ╭──────────────────╮                ┌────────────┐
│          │──credentials──▶│                  │◀──job details──│            │
│          │──application──▶│                  │◀──hiring──────-│            │
│  WORKER  │──message──────▶│   0.0            │◀──top-up───────│  EMPLOYER  │
│          │                │   KAYA           │                │            │
│          │◀──job match────│                  │──applicants───▶│            │
│          │◀──balance──────│                  │──directory────▶│            │
│          │◀──notice───────│                  │──receipt──────▶│            │
└──────────┘                ╰──────────────────╯                └────────────┘
                                   ▲   │
                             result │   │checkout
                                    │   ▼
                            ┌───────┴──────┐
                            │   PAYMONGO   │
                            └──────────────┘
```

---

## Level 1

```
┌──────────┐                ╭──────────────────────╮        ┌────┬──────────────────┐
│          │──credentials──▶│  1.0                 │───────▶│ D1 │ users            │
│  WORKER  │                │  Manage Account      │◀───────│    │                  │
│    +     │◀──session──────│  and Verification    │        └────┴──────────────────┘
│ EMPLOYER │                │                      │───────▶┌────┬──────────────────┐
│          │──ID document──▶│                      │◀───────│ D2 │ verifications    │
└──────────┘                ╰──────────────────────╯        └────┴──────────────────┘
                              ▲            │
                       ruling │            │ verified account
              ┌──────────┐    │            ▼
              │  ADMIN   │────┘   ╭──────────────────────╮  ┌────┬──────────────────┐
              └──────────┘        │  2.0                 │─▶│ D3 │ worker_profiles  │
┌──────────┐                      │  Manage Profiles     │◀─│ D4 │ employer_profiles│
│  WORKER  │──profile details────▶│                      │  └────┴──────────────────┘
│    +     │                      │                      │─▶┌────┬──────────────────┐
│ EMPLOYER │◀──public profile─────│                      │◀─│ D5 │ locations        │
└──────────┘                      ╰──────────────────────╯  └────┴──────────────────┘
                                            │
                                            │ role
                                            ▼
┌──────────┐                ╭──────────────────────╮        ┌────┬──────────────────┐
│          │──job details──▶│  3.0                 │───────▶│ D6 │ jobs_posts       │
│ EMPLOYER │                │  Post and            │◀───────│    │                  │
│          │◀──live post────│  Maintain Job        │        └────┴──────────────────┘
└──────────┘                ╰──────────────────────╯
┌──────────┐                     ▲       │
│  TIMER   │──sweep──────────────┘       │ open posts
└──────────┘                             ▼
┌──────────┐                ╭──────────────────────╮
│  WORKER  │──query────────▶│  4.0                 │◀──profiles── D3, D4
│    +     │                │  Search and Match    │◀──boosts──── D11
│ EMPLOYER │◀──ranked list──│                      │◀──posts───── D6
└──────────┘                ╰──────────────────────╯
                                     │
                                     │ chosen job / worker
                                     ▼
┌──────────┐                ╭──────────────────────╮        ┌────┬──────────────────┐
│  WORKER  │──application──▶│  5.0                 │───────▶│ D7 │ applications     │
│          │◀──result───────│  Handle Application  │◀───────│    │                  │
└──────────┘                │  and Hiring          │        └────┴──────────────────┘
┌──────────┐                │                      │───────▶┌────┬──────────────────┐
│ EMPLOYER │──decision─────▶│                      │◀───────│ D8 │ invitations      │
│          │◀──applicants───│                      │        └────┴──────────────────┘
└──────────┘                ╰──────────────────────╯
                              │            ▲
                       charge │            │ balance, refund
                              ▼            │
┌──────────┐                ╭──────────────────────╮        ┌────┬──────────────────┐
│ PAYMONGO │──result───────▶│  6.0                 │───────▶│ D9 │ credit_wallets   │
│          │◀──checkout─────│  Manage Barya        │◀───────│    │                  │
└──────────┘                │                      │        └────┴──────────────────┘
┌──────────┐                │                      │───────▶┌────┬──────────────────┐
│  WORKER  │──top-up───────▶│                      │◀───────│D10 │credit_transactions│
│    +     │                │                      │        └────┴──────────────────┘
│ EMPLOYER │◀──balance──────│                      │───────▶┌────┬──────────────────┐
└──────────┘                ╰──────────────────────╯        │D11 │ boosts           │
                                     ▲                      └────┴──────────────────┘
                                     │ hired pair
                                     │
┌──────────┐                ╭──────────────────────╮        ┌────┬──────────────────┐
│  WORKER  │──message──────▶│  7.0                 │───────▶│D12 │ conversations    │
│    +     │                │  Communicate         │◀───────│D13 │ messages         │
│ EMPLOYER │◀──thread───────│  and Schedule        │        └────┴──────────────────┘
│          │──day, time────▶│                      │───────▶┌────┬──────────────────┐
│          │◀──days taken───│                      │◀───────│D14 │schedule_proposals│
└──────────┘                ╰──────────────────────╯        └────┴──────────────────┘
                                     │
                                     │ finished work
                                     ▼
┌──────────┐                ╭──────────────────────╮        ┌────┬──────────────────┐
│  WORKER  │──rating───────▶│  8.0                 │───────▶│D15 │ reviews          │
│    +     │                │  Build Reputation    │◀───────│    │                  │
│ EMPLOYER │◀──score, badge─│                      │        └────┴──────────────────┘
└──────────┘                ╰──────────────────────╯
                                     │
                                     │ event
                                     ▼
┌──────────┐                ╭──────────────────────╮        ┌────┬──────────────────┐
│  WORKER  │                │  9.0                 │───────▶│D16 │user_notifications│
│    +     │◀──notice───────│  Notify              │◀───────│    │                  │
│ EMPLOYER │                │                      │        └────┴──────────────────┘
└──────────┘                ╰──────────────────────╯

┌──────────┐                ╭──────────────────────╮        ┌────┬──────────────────┐
│  WORKER  │──post─────────▶│  10.0                │───────▶│D17 │community_posts   │
│    +     │                │  Community Board     │        └────┴──────────────────┘
│ EMPLOYER │◀─chat──────────│                      │
└──────────┘                ╰──────────────────────╯
┌──────────┐                ╭──────────────────────╮        ┌────┬──────────────────┐
│ EMPLOYER │──crew size────▶│  11.0                │───────▶│ D6 │jobs_posts        │
│          │◀─roster────────│  Staff a Crew        │───────▶│ D7 │applications      │
└──────────┘                ╰──────────────────────╯        └────┴──────────────────┘
┌──────────┐                ╭──────────────────────╮        ┌────┬──────────────────┐
│  WORKER  │──answers──────▶│  12.0                │───────▶│D18 │assessment_attempts│
│          │◀─result────────│  Skill Check         │◀───────│D19 │skill_assessments │
└──────────┘                ╰──────────────────────╯        └────┴──────────────────┘
```

---

## Level 2 — 1.0 Manage Account and Verification

```
┌──────────┐              ╭──────────────────╮          ┌────┬────────────────┐
│  WORKER  │──details────▶│ 1.1 Register     │─account─▶│ D1 │ users          │
│    +     │              ╰──────────────────╯          └────┴────────────────┘
│ EMPLOYER │                                                   ▲   │
│          │──credentials▶╭──────────────────╮                 │   │ account
│          │◀──session────│ 1.2 Authenticate │─────────────────┘   │
│          │              ╰──────────────────╯                     │
│          │                                                       │
│          │──ID document▶╭──────────────────╮          ┌────┬─────▼──────────┐
│          │              │ 1.3 Submit       │─document▶│ D2 │ verifications  │
│          │              │     documents    │          └────┴────────────────┘
│          │              ╰──────────────────╯                 ▲   │
│          │                                          submitted│   │ decision
│          │◀──status─────╭──────────────────╮                 │   │
└──────────┘              │ 1.5 Gate         │◀────────────────┘   │
                          │     transacting  │                     │
                          ╰──────────────────╯                     │
┌──────────┐              ╭──────────────────╮                     │
│  ADMIN   │──ruling─────▶│ 1.4 Review       │─────────────────────┘
│          │◀──queue──────│     documents    │
└──────────┘              ╰──────────────────╯
```

## Level 2 — 2.0 Manage Profiles

```
┌──────────┐              ╭──────────────────╮          ┌────┬────────────────┐
│  WORKER  │──details────▶│ 2.1 Create       │─profile─▶│ D3 │worker_profiles │
│    +     │              │     profile      │          │ D4 │employer_profil.│
│ EMPLOYER │              ╰──────────────────╯          └────┴────────────────┘
│          │                                                  ▲   │
│          │──name───────▶╭──────────────────╮        name    │   │ stored name
│          │◀──locked─────│ 2.2 Lock the name│────────────────┘   │
│          │              ╰──────────────────╯                    │
│          │                                                      │
│          │──place──────▶╭──────────────────╮          ┌────┬────▼───────────┐
│          │◀──suggestion─│ 2.3 Set location │◀─match──▶│ D5 │ locations      │
│          │              ╰──────────────────╯          └────┴────────────────┘
│          │
│          │──skill──────▶╭──────────────────╮
│          │              │ 2.4 Manage skills│──skill──▶ D3
│          │              ╰──────────────────╯
│          │
│          │◀──profile────╭──────────────────╮
└──────────┘              │ 2.5 Publish      │◀──profile, badges, record── D3, D15
                          │     public view  │
                          ╰──────────────────╯
```

## Level 2 — 3.0 Post and Maintain Job

```
┌──────────┐              ╭──────────────────╮
│ EMPLOYER │──details────▶│ 3.1 Compose post │──draft──┐
│          │◀──errors─────╰──────────────────╯         │
│          │                                            ▼
│          │              ╭──────────────────╮    ┌────┬────────────────┐
│          │◀──live post───│ 3.2 Publish      │───▶│ D6 │ jobs_posts     │
│          │              ╰──────────────────╯    └────┴────────────────┘
│          │                                            ▲   │
│          │              ╭──────────────────╮  post    │   │ due posts
│          │◀──warning────│ 3.3 Warn before  │◀─────────┘   │
│          │              │     expiry       │              │
│          │              ╰──────────────────╯              │
│          │                                                │
│          │              ╭──────────────────╮◀─────────────┘
│          │◀──expired────│ 3.4 Expire and   │──status──▶ D6
│          │              │     refund       │──refund──▶ 6.0
│          │              ╰──────────────────╯
│          │
│          │──block──────▶╭──────────────────╮──charge──▶ 6.0
│          │◀──new date───│ 3.5 Extend       │──date────▶ D6
│          │              ╰──────────────────╯
│          │
│          │──boost──────▶╭──────────────────╮──charge──▶ 6.0
└──────────┘              │ 3.6 Boost        │──boost───▶ D11
                          ╰──────────────────╯
┌──────────┐
│  TIMER   │──sweep──────▶ 3.3, 3.4
└──────────┘
```

## Level 2 — 4.0 Search and Match

```
┌──────────┐              ╭──────────────────╮
│  WORKER  │──query──────▶│ 4.1 Filter       │◀──posts──── D6
│    +     │  filters     │                  │◀──profiles─ D3, D4
│ EMPLOYER │              ╰──────────────────╯◀──place──── D5
│          │                       │
│          │                       │ candidates
│          │                       ▼
│          │              ╭──────────────────╮
│          │              │ 4.2 Score and    │◀──rating, jobs done, distance── D3, D7
│          │              │     rank         │
│          │              ╰──────────────────╯
│          │                       │
│          │                       │ ordered set
│          │                       ▼
│          │              ╭──────────────────╮
│          │              │ 4.3 Lift boosted │◀──active boosts── D11
│          │              ╰──────────────────╯
│          │                       │
│          │                       │ page
│          │                       ▼
│          │◀──ranked list─╭──────────────────╮
└──────────┘              │ 4.4 Return page  │
                          ╰──────────────────╯
```

## Level 2 — 5.0 Handle Application and Hiring

```
┌──────────┐              ╭──────────────────╮──charge──▶ 6.0
│  WORKER  │──application▶│ 5.1 Apply        │─────────▶┌────┬────────────────┐
│          │◀──receipt────╰──────────────────╯          │ D7 │ applications   │
│          │                                            └────┴────────────────┘
│          │              ╭──────────────────╮                ▲   │
│          │◀──invitation─│ 5.2 Invite       │──charge──▶ 6.0 │   │ applicants
│          │              ╰──────────────────╯──────────▶ D8  │   │
│          │                       ▲                          │   │
│          │                       │ invite                   │   │
└──────────┘              ┌────────┴─────────┐                │   │
                          │    EMPLOYER      │                │   │
                          └────────┬─────────┘                │   │
                                   │ decision                 │   │
                                   ▼                          │   │
                          ╭──────────────────╮◀───────────────┴───┘
                          │ 5.3 Decide       │──status──▶ D7
                          ╰──────────────────╯──event───▶ 9.0
                                   │
                                   │ hire
                                   ▼
                          ╭──────────────────╮          ┌────┬────────────────┐
                          │ 5.4 Open thread  │─thread──▶│D12 │ conversations  │
                          ╰──────────────────╯          └────┴────────────────┘
                                   │
                                   │ work done
                                   ▼
┌──────────┐              ╭──────────────────╮
│  WORKER  │──confirm────▶│ 5.5 Confirm      │──status──▶ D7, D6
│    +     │              │     completion   │──event───▶ 8.0, 9.0
│ EMPLOYER │◀──completed──╰──────────────────╯
└──────────┘
```

## Level 2 — 6.0 Manage Barya

```
                          ╭──────────────────╮          ┌────┬────────────────┐
     signup, month ──────▶│ 6.1 Grant        │─credit──▶│ D9 │ credit_wallets │
                          ╰──────────────────╯          └────┴────────────────┘
┌──────────┐                                                  ▲   │
│  WORKER  │──top-up─────▶╭──────────────────╮        balance │   │
│    +     │              │ 6.2 Top up       │────────────────┘   │
│ EMPLOYER │◀──balance────╰──────────────────╯                    │
└──────────┘                   │        ▲                         │
                     checkout  │        │ result                  │
                               ▼        │                         │
                          ┌──────────────────┐                    │
                          │    PAYMONGO      │                    │
                          └──────────────────┘                    │
                                   │                              │
                                   │ webhook                      │
                                   ▼                              │
                          ╭──────────────────╮                    │
                          │ 6.5 Reconcile    │──settled──▶ D9, D10│
                          ╰──────────────────╯                    │
                                                                  │
     apply, invite ──────▶╭──────────────────╮◀───────────────────┘
     boost, duration      │ 6.3 Charge       │──line────▶┌────┬───────────────┐
                          ╰──────────────────╯           │D10 │credit_transac.│
                                   │                     └────┴───────────────┘
                          refused  │ charged                   ▲
                                   ▼                           │
     expiry, cancel ─────▶╭──────────────────╮──reversal───────┘
                          │ 6.4 Refund       │──credit──▶ D9
                          ╰──────────────────╯
```

## Level 2 — 7.0 Communicate and Schedule

```
┌──────────┐              ╭──────────────────╮          ┌────┬────────────────┐
│  WORKER  │──message────▶│ 7.1 Send message │─message─▶│D13 │ messages       │
│    +     │◀──thread─────╰──────────────────╯◀─────────│D12 │ conversations  │
│ EMPLOYER │                                            └────┴────────────────┘
│          │
│          │──day, time──▶╭──────────────────╮          ┌────┬────────────────┐
│          │              │ 7.2 Propose day  │─offer───▶│D14 │schedule_propos.│
│          │◀──offer──────╰──────────────────╯          └────┴────────────────┘
│          │                                                  ▲   │
│          │──accept,────▶╭──────────────────╮        offer   │   │ agreed
│          │   decline    │ 7.3 Answer       │────────────────┘   │
│          │◀──result─────╰──────────────────╯──event──▶ 9.0      │
│          │                                                      │
│          │◀──days taken─╭──────────────────╮◀─────────────────--┘
└──────────┘              │ 7.4 Report days  │
                          │     taken        │──days───▶ 5.0
                          ╰──────────────────╯
```

## Level 2 — 8.0 Build Reputation

```
┌──────────┐              ╭──────────────────╮          ┌────┬────────────────┐
│  WORKER  │──rating─────▶│ 8.1 Leave review │─review──▶│D15 │ reviews        │
│    +     │◀──posted─────╰──────────────────╯          └────┴────────────────┘
│ EMPLOYER │                                                  │
│          │              ╭──────────────────╮◀───────────────┘
│          │              │ 8.2 Compute      │◀──finished, cancelled── D7
│          │              │     record       │
│          │              ╰──────────────────╯
│          │                       │ record
│          │                       ▼
│          │◀──badges─────╭──────────────────╮
│          │              │ 8.3 Award badges │◀──verification── D2
│          │              ╰──────────────────╯
│          │
│          │◀──years──────╭──────────────────╮
└──────────┘              │ 8.4 Total        │◀──experience rows── D3
                          │     experience   │
                          ╰──────────────────╯
```

## Level 2 — 9.0 Notify

```
   3.0, 5.0, 6.0 ────────▶╭──────────────────╮
   7.0, 8.0        event  │ 9.1 Raise event  │
                          ╰──────────────────╯
                                   │ event
                                   ▼
                          ╭──────────────────╮
                          │ 9.2 Pick audience│◀──roles── D3, D4
                          ╰──────────────────╯
                                   │ addressed notice
                                   ▼
┌──────────┐              ╭──────────────────╮          ┌────┬────────────────┐
│  WORKER  │◀──notice─────│ 9.3 Deliver      │─notice──▶│D16 │user_notificat. │
│    +     │              ╰──────────────────╯          └────┴────────────────┘
│ EMPLOYER │                                                  ▲   │
│          │──opened─────▶╭──────────────────╮                │   │
└──────────┘              │ 9.4 Mark read    │────────────────┘   │
                          ╰──────────────────╯◀───────────────────┘
```

---

## Level 3 — 5.3 Decide

```
   from 5.1, 5.2 ────────▶╭──────────────────╮◀──post status── D6
      decision            │ 5.3.1 Check the  │
                          │       post is    │
                          │       live       │
                          ╰──────────────────╯
                                   │ live
                                   ▼
                          ╭──────────────────╮
                          │ 5.3.2 Charge the │──charge──▶ 6.0
                          │       applicant  │◀──result──
                          ╰──────────────────╯
                                   │ paid
                                   ▼
                          ╭──────────────────╮          ┌────┬────────────────┐
                          │ 5.3.3 Record the │─status──▶│ D7 │ applications   │
                          │       hire       │─status──▶│ D6 │ jobs_posts     │
                          ╰──────────────────╯          └────┴────────────────┘
                                   │ hire
                                   ▼
┌──────────┐              ╭──────────────────╮
│ EMPLOYER │◀──days taken─│ 5.3.4 Show other │◀──agreed days── D14
└──────────┘              │       commitments│
                          ╰──────────────────╯
                                   │ hire
                                   ▼
                          ╭──────────────────╮
                          │ 5.3.5 Notify     │──event──▶ 9.0
                          │       both       │
                          ╰──────────────────╯
```

## Level 3 — 6.3 Charge

```
   apply, invite ────────▶╭──────────────────╮
   boost, duration        │ 6.3.1 Price the  │◀──price list── config
      action              │       action     │
                          ╰──────────────────╯
                                   │ amount
                                   ▼
                          ╭──────────────────╮          ┌────┬────────────────┐
                          │ 6.3.2 Check the  │◀─balance─│ D9 │ credit_wallets │
                          │       balance    │          └────┴────────────────┘
                          ╰──────────────────╯
                             │            │
                    refused  │            │ approved
                             ▼            ▼
                    ┌────────────┐  ╭──────────────────╮      ┌────┬───────────────┐
                    │ CALLER     │  │ 6.3.3 Write the  │─line▶│D10 │credit_transac.│
                    │ (refusal)  │  │       ledger line│─bal─▶│ D9 │credit_wallets │
                    └────────────┘  ╰──────────────────╯      └────┴───────────────┘
                                             │
                                     failure │
                                             ▼
                                    ╭──────────────────╮
                                    │ 6.3.4 Roll back  │──reversal──▶ D9, D10
                                    ╰──────────────────╯
```

## Level 3 — 7.2 Propose day

```
┌──────────┐              ╭──────────────────╮          ┌────┬────────────────┐
│  WORKER  │──day, time──▶│ 7.2.1 Read days  │◀─agreed─-│D14 │schedule_propos.│
│    +     │              │       taken      │          └────┴────────────────┘
│ EMPLOYER │              ╰──────────────────╯                ▲   │
│          │                       │ days taken               │   │
│          │                       ▼                          │   │
│          │              ╭──────────────────╮                │   │
│          │              │ 7.2.2 Supersede  │──status────────┘   │
│          │              │       live offer │                    │
│          │              ╰──────────────────╯                    │
│          │                       │ clear                        │
│          │                       ▼                              │
│          │              ╭──────────────────╮                    │
│          │              │ 7.2.3 Record the │──offer─────────────┘
│          │              │       offer      │
│          │              ╰──────────────────╯
│          │                       │ offer
│          │                       ▼
│          │◀──card───────╭──────────────────╮
└──────────┘              │ 7.2.4 Show it to │──event──▶ 9.0
                          │       both       │
                          ╰──────────────────╯
```
