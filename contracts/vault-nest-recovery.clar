;; VaultNest Recovery Contract
;; Enhanced recovery mechanism with safety features

;; Constants
(define-constant err-not-authorized (err u200))
(define-constant err-invalid-state (err u201))
(define-constant err-cooldown-active (err u202))

;; Recovery request tracking
(define-map recovery-requests
  { vault-owner: principal }
  {
    initiator: principal,
    requested-at: uint,
    status: (string-ascii 20)
  }
)

(define-public (initiate-recovery (vault-owner principal))
  (let (
    (vault (unwrap! (contract-call? .vault-nest get-vault-data vault-owner) err-vault-not-found))
    (recovery-address (unwrap! (get recovery-address vault) (err u200)))
  )
  (begin
    (asserts! (is-eq tx-sender recovery-address) err-not-authorized)
    (try! (create-recovery-request vault-owner))
    (ok true)
  ))
)

(define-private (create-recovery-request (vault-owner principal))
  (begin
    (map-set recovery-requests
      { vault-owner: vault-owner }
      {
        initiator: tx-sender,
        requested-at: block-height,
        status: "pending"
      }
    )
    (ok true)
  )
)

(define-read-only (get-recovery-status (vault-owner principal))
  (map-get? recovery-requests { vault-owner: vault-owner })
)
