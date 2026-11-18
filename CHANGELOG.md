# Changelog

## Unreleased

### Added
- PACE Together invitations, two-member shared goals, author-attributed daily logs, and a unified completed-entry Journey.
- Individual streak, consistency, activity, session, and time metrics alongside combined collaboration totals.
- Owner-consented solo-goal conversion. Shared copies are prepared privately, source records and local evidence remain intact, and the original solo goal is archived only after acceptance.
- Shared deadline display uses a date-only value so collaborators in different time zones see the same target date.
- Invitation, membership, shared-goal, and author-only log Security Rules.

### Data and retention
- A member leaving or an owner ending a collaboration revokes the former member's access without deleting shared history. The owner retains read-only access to ended collaborations.
- Photo binaries remain on the contributor's device. Remote collaborators see an unavailable/not-shared state; Firebase Storage is not used.
- Existing composite indexes cover current queries; no new composite index is required. Rules and indexes have not been deployed.
