# Roadmap

Deferred work remains unscaffolded until the required `v0.1.0` assessment
release is published and independently verified.

## Golden tests

Question: When should visual golden tests be added?

Answer: Only after the released feed, post card, sheets, offline, empty, and
error states pass the required real journeys and manual Figma overlay.

Reason/trade-off: The assessment needs behavioural confidence and asset fidelity
first; unstable or speculative golden infrastructure would consume delivery time.

Revisit trigger: `v0.1.0` is published, installed from GitHub Releases, and its
three journeys and manual visual gate have passed.

## Commitlint

Question: When should Conventional Commit enforcement be added?

Answer: After the verified `v0.1.0` assessment release, through Beads issue
`expert-listing-cnr.11`.

Reason/trade-off: The approved task commit messages already follow Conventional
Commits. Adding a hook or CI gate now introduces tooling and release risk without
improving the required product journey.

Revisit trigger: The release gate above passes. The smallest complete slice adds
local and CI validation for the documented commit-message policy.
