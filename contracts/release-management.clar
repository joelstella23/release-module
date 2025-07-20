;; Release Management Smart Contract
;; Manages blockchain-based release tracking, verification, and reward distribution

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-RELEASE-NOT-FOUND (err u101))
(define-constant ERR-RELEASE-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-PARAMETERS (err u103))
(define-constant ERR-ALREADY-REGISTERED (err u104))
(define-constant ERR-NOT-REGISTERED (err u105))
(define-constant ERR-INSUFFICIENT-STAKE (err u106))
(define-constant ERR-RELEASE-FULL (err u107))
(define-constant ERR-RELEASE-ENDED (err u108))
(define-constant ERR-RELEASE-NOT-STARTED (err u109))
(define-constant ERR-RELEASE-ACTIVE (err u110))
(define-constant ERR-INVALID-CONTRIBUTION (err u111))
(define-constant ERR-REWARDS-ALREADY-CLAIMED (err u112))

;; Constants
(define-constant ADMIN-ROLE "admin")
(define-constant CONTRIBUTOR-ROLE "contributor")
(define-constant MIN-RELEASE-DURATION u86400) ;; 1 day in seconds
(define-constant MAX-RELEASE-DURATION u2592000) ;; 30 days in seconds

;; Carry over the existing implementation's core logic
(define-map authorized-roles
  {
    role: (string-ascii 20),
    address: principal,
  }
  { authorized: bool }
)

(define-map releases
  { release-id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 500),
    creator: principal,
    is-official: bool,
    start-time: uint,
    end-time: uint,
    contribution-goal: uint,
    max-contributors: uint,
    reward-pool: uint, ;; in microSTX
    is-active: bool,
    is-ended: bool,
    contributors-count: uint,
  }
)

(define-map contribution
  {
    release-id: uint,
    contributor: principal,
  }
  {
    registered-at: uint,
    total-contribution: uint,
    last-update: uint,
    stake-amount: uint, ;; in microSTX
    reward-claimed: bool,
  }
)

(define-map release-leaderboard
  { release-id: uint }
  { contributors: (list 50 {
    contributor: principal,
    total-contribution: uint,
  }) }
)

(define-map achievements
  {
    release-id: uint,
    contributor: principal,
  }
  {
    completed-release: bool,
    reached-contribution-goal: bool,
  }
)

(define-data-var next-release-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Carried over core private helper functions
(define-private (is-owner (caller principal))
  (is-eq caller (var-get contract-owner))
)

(define-private (release-exists (release-id uint))
  (is-some (map-get? releases { release-id: release-id }))
)

(define-private (is-release-active (release-id uint))
  (let ((release (unwrap! (map-get? releases { release-id: release-id }) false)))
    (and
      (get is-active release)
      (not (get is-ended release))
      (>= block-height (get start-time release))
      (< block-height (get end-time release))
    )
  )
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-owner new-owner))
  )
)

(define-public (grant-role
    (role (string-ascii 20))
    (address principal)
  )
  (begin
    (asserts! (is-owner tx-sender) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-roles {
      role: role,
      address: address,
    } { authorized: true }
    ))
  )
)

(define-public (revoke-role
    (role (string-ascii 20))
    (address principal)
  )
  (begin
    (asserts! (is-owner tx-sender) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-roles {
      role: role,
      address: address,
    } { authorized: false }
    ))
  )
)

;; Read-only functions for retrieving release and contribution data
(define-read-only (get-release (release-id uint))
  (map-get? releases { release-id: release-id })
)

(define-read-only (get-contributor-data
    (release-id uint)
    (contributor principal)
  )
  (map-get? contribution {
    release-id: release-id,
    contributor: contributor,
  })
)