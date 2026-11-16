# Individual contribution log

> Fill this in with **your own** words as you work. It supports the "originality and individual contribution" marks and helps you prepare for questions: for every item you should be able to explain *why* it is there.

**Author:** PES1UG24CS637  **Repository:** https://github.com/tanshanbhogue/High-frequency-Trading-platform

## What I designed myself
- [ ] The business rules (e.g. why trades must reference a routed exchange)
- [ ] My own choices in the data (algorithms, securities, portfolios)
- [ ] Anything I changed or extended after generating the first version

## Work log
| Date | What I did | What I learned / decided | Commit |
|---|---|---|---|
| | | | |

## Tools and sources used
| Tool / source | What for | What I checked or changed myself |
|---|---|---|
| AI assistant | Generating the initial schema, scripts and app | |
| MySQL 8 / MongoDB / Next.js documentation | | |

## Questions I should be able to answer
1. Why a composite foreign key from `orders` to `portfolio_owners`?
2. Why is ownership "= 100 %" a view and not a trigger?
3. Why can the trader account not `INSERT` into `orders` directly?
4. What does `trg_trades_sync_status` do, and why a trigger instead of application code?
5. When is MongoDB the better choice than a MySQL table?
6. Which layer really enforces access control, and how would you prove it?
