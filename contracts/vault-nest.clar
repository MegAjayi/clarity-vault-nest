;; VaultNest Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-vault-locked (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-vault-not-found (err u103))

;; Data Variables
(define-map vaults
  { owner: principal }
  {
    balance: uint,
    locked-until: uint,
    recovery-address: (optional principal),
    multi-sig-required: bool
  }
)

;; Public Functions
(define-public (create-vault (recovery-address (optional principal)) (multi-sig bool))
  (begin
    (asserts! (is-none (get-vault-data tx-sender)) (err u104))
    (ok (map-set vaults
      { owner: tx-sender }
      {
        balance: u0,
        locked-until: u0,
        recovery-address: recovery-address,
        multi-sig-required: multi-sig
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
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (ok (map-set vaults
      { owner: tx-sender }
      (merge vault { balance: new-balance })
    ))
  ))
)

(define-public (withdraw (amount uint))
  (let (
    (vault (unwrap! (get-vault-data tx-sender) err-vault-not-found))
  )
  (begin
    (asserts! (<= amount (get balance vault)) err-invalid-amount)
    (asserts! (is-unlocked vault) err-vault-locked)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (ok (map-set vaults
      { owner: tx-sender }
      (merge vault { balance: (- (get balance vault) amount) })
    ))
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
  multi-sig-required: bool
}))
  (< (get locked-until vault) block-height)
)
