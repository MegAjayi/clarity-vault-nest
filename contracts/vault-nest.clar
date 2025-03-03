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
(define-constant err-limit-exceeded (err u107))
(define-constant err-paused (err u108))

;; Data Variables
(define-data-var operation-status uint u0)
(define-data-var contract-paused bool false)
(define-data-var withdrawal-limit uint u1000000000)

(define-map vaults
  { owner: principal }
  {
    balance: uint,
    locked-until: uint,
    recovery-address: (optional principal),
    multi-sig-required: bool,
    last-operation: uint,
    cooldown-period: uint,
    daily-limit: uint
  }
)

;; Events
(define-data-var last-event-id uint u0)

;; Administrative Functions
(define-public (set-withdrawal-limit (new-limit uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (var-set withdrawal-limit new-limit)
    (ok true)
  )
)

(define-public (toggle-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok true)
  )
)

;; Enhanced Vault Configuration
(define-public (update-vault-config 
  (cooldown-period uint)
  (daily-limit uint)
)
  (let (
    (vault (unwrap! (get-vault-data tx-sender) err-vault-not-found))
  )
  (begin
    (map-set vaults
      { owner: tx-sender }
      (merge vault {
        cooldown-period: cooldown-period,
        daily-limit: daily-limit
      })
    )
    (ok true)
  ))
)

[Previous functions remain unchanged...]

;; Enhanced withdrawal with limits
(define-public (withdraw (amount uint))
  (let (
    (vault (unwrap! (get-vault-data tx-sender) err-vault-not-found))
  )
  (begin
    (asserts! (not (var-get contract-paused)) err-paused)
    (try! (check-reentrancy))
    (asserts! (<= amount (get balance vault)) err-invalid-amount)
    (asserts! (<= amount (get daily-limit vault)) err-limit-exceeded)
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
