;; title: apartment_building_maintenance_registry
;; version: 1.0.0
;; summary: Smart contract for Apartment Building Maintenance Registry

(define-constant ERR-NOT-FOUND u404)
(define-constant ERR-UNAUTHORIZED u403)
(define-constant ERR-INVALID-INPUT u400)
(define-constant ERR-ALREADY-EXISTS u409)

(define-data-var next-maintenance-id uint u1)
(define-data-var contract-owner principal tx-sender)

(define-map maintenance-records
  { maintenance-id: uint }
  {
    unit-number: (string-ascii 10),
    issue-description: (string-ascii 200),
    status: (string-ascii 20),
    assigned-to: principal,
    created-at: uint,
    completed-at: (optional uint),
    priority: (string-ascii 10)
  }
)

(define-map unit-maintenance-count
  { unit-number: (string-ascii 10) }
  { count: uint }
)

(define-map maintenance-assignments
  { assigned-to: principal }
  { total-assigned: uint }
)

(define-read-only (get-maintenance-record (maintenance-id uint))
  (map-get? maintenance-records { maintenance-id: maintenance-id })
)

(define-read-only (get-unit-maintenance-count (unit-number (string-ascii 10)))
  (map-get? unit-maintenance-count { unit-number: unit-number })
)

(define-read-only (get-assigned-count (technician principal))
  (map-get? maintenance-assignments { assigned-to: technician })
)

(define-public (create-maintenance-record
  (unit-number (string-ascii 10))
  (issue-description (string-ascii 200))
  (priority (string-ascii 10))
)
  (let
    (
      (record-id (var-get next-maintenance-id))
    )
    (if (or (is-eq (len unit-number) u0) (is-eq (len issue-description) u0))
      (err ERR-INVALID-INPUT)
      (begin
        (map-set maintenance-records
          { maintenance-id: record-id }
          {
            unit-number: unit-number,
            issue-description: issue-description,
            status: "open",
            assigned-to: tx-sender,
            created-at: burn-block-height,
            completed-at: none,
            priority: priority
          }
        )
        (var-set next-maintenance-id (+ record-id u1))
        (ok record-id)
      )
    )
  )
)

(define-public (assign-maintenance (maintenance-id uint) (technician principal))
  (let
    (
      (record (map-get? maintenance-records { maintenance-id: maintenance-id }))
    )
    (if (is-none record)
      (err ERR-NOT-FOUND)
      (begin
        (map-set maintenance-records
          { maintenance-id: maintenance-id }
          (merge (unwrap-panic record) { assigned-to: technician })
        )
        (ok true)
      )
    )
  )
)

(define-public (update-maintenance-status (maintenance-id uint) (new-status (string-ascii 20)))
  (let
    (
      (record (map-get? maintenance-records { maintenance-id: maintenance-id }))
    )
    (if (is-none record)
      (err ERR-NOT-FOUND)
      (begin
        (map-set maintenance-records
          { maintenance-id: maintenance-id }
          (merge
            (unwrap-panic record)
            {
              status: new-status,
              completed-at: (if (is-eq new-status "completed") (some burn-block-height) none)
            }
          )
        )
        (ok true)
      )
    )
  )
)

(define-public (complete-maintenance (maintenance-id uint))
  (let
    (
      (record (map-get? maintenance-records { maintenance-id: maintenance-id }))
    )
    (if (or (is-none record) (not (is-eq tx-sender (get assigned-to (unwrap-panic record)))))
      (err ERR-UNAUTHORIZED)
      (begin
        (map-set maintenance-records
          { maintenance-id: maintenance-id }
          (merge (unwrap-panic record) { status: "completed", completed-at: (some burn-block-height) })
        )
        (ok true)
      )
    )
  )
)
