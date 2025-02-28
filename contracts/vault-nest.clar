;; VaultNest Contract
;; Enhanced version with security features and event emission

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-vault-locked (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-vault-not-found (err u103))
(define-constant err-vault-exists (err u104))
(define-constant err-reentrancy (err u105))
(define-constant err-cooldown-active (err u106))

;; Data Variables
(define-data-var operation-status uint u0)

(define-map vaults
  { owner: principal }
  {
    balance: uint,
    locked-until: uint,
    recovery-address: (optional principal),
    multi-sig-required: bool,
    last-operation: uint
  }
)

;; Events
(define-data-var last-event-id uint u0)

(define-public (emit-vault-event (event-type (string-ascii 24)) (vault-owner principal) (amount uint))
  (begin
    (var-set last-event-id (+ (var-get last-event-id) u1))
    (print { event-id: (var-get last-event-id), type: event-type, owner: vault-owner, amount: amount })
    (ok true)
  )
)

;; Reentrancy Protection
(define-private (check-reentrancy)
  (begin
    (asserts! (is-eq (var-get operation-status) u0) err-reentrancy)
    (var-set operation-status u1)
    (ok true)
  )
)

(define-private (clear-reentrancy)
  (begin
    (var-set operation-status u0)
    (ok true)
  )
)

;; Public Functions
(define-public (create-vault (recovery-address (optional principal)) (multi-sig bool))
  (begin
    (asserts! (is-none (get-vault-data tx-sender)) err-vault-exists)
    (try! (emit-vault-event "vault-created" tx-sender u0))
    (ok (map-set vaults
      { owner: tx-sender }
      {
        balance: u0,
        locked-until: u0,
        recovery-address: recovery-address,
        multi-sig-required: multi-sig,
        last-operation: block-height
      }
    ))
  )
)

(define-public (deposit (amount uint))
  (let (
    (vault (unwrap! (get-vault-data tx-sender) err-vault-not-found))
    (new-balance (+ (get balance vault) amount))
  )
  (begin
    (try! (check-reentrancy))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (try! (emit-vault-event "deposit" tx-sender amount))
    (map-set vaults
      { owner: tx-sender }
      (merge vault { 
        balance: new-balance,
        last-operation: block-height 
      })
    )
    (try! (clear-reentrancy))
    (ok true)
  ))
)

(define-public (withdraw (amount uint))
  (let (
    (vault (unwrap! (get-vault-data tx-sender) err-vault-not-found))
  )
  (begin
    (try! (check-reentrancy))
    (asserts! (<= amount (get balance vault)) err-invalid-amount)
    (asserts! (is-unlocked vault) err-vault-locked)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (try! (emit-vault-event "withdraw" tx-sender amount))
    (map-set vaults
      { owner: tx-sender }
      (merge vault { 
        balance: (- (get balance vault) amount),
        last-operation: block-height 
      })
    )
    (try! (clear-reentrancy))
    (ok true)
  ))
)

;; Read Only Functions
(define-read-only (get-vault-data (owner principal))
  (map-get? vaults { owner: owner })
)

(define-read-only (is-unlocked (vault {
  balance: uint,
  locked-until: uint,
  recovery-address: (optional principal),
  multi-sig-required: bool,
  last-operation: uint
}))
  (< (get locked-until vault) block-height)
)
