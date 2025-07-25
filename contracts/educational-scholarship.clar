;; Educational Scholarship Coordination Contract
;; Manages scholarship fund distribution and student applications

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-ALREADY-EXISTS (err u301))
(define-constant ERR-NOT-FOUND (err u302))
(define-constant ERR-INVALID-INPUT (err u303))
(define-constant ERR-INSUFFICIENT-FUNDS (err u304))
(define-constant ERR-ALREADY-AWARDED (err u305))
(define-constant ERR-APPLICATION-CLOSED (err u306))

;; Data Variables
(define-data-var next-scholarship-id uint u1)
(define-data-var next-student-id uint u1)
(define-data-var next-application-id uint u1)
(define-data-var total-fund-balance uint u0)

;; Data Maps
(define-map scholarships
  { scholarship-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    amount: uint,
    max-recipients: uint,
    current-recipients: uint,
    eligibility-criteria: (string-ascii 300),
    application-deadline: uint,
    academic-year: (string-ascii 20),
    field-of-study: (string-ascii 100),
    is-active: bool,
    created-at: uint
  }
)

(define-map students
  { student-id: uint }
  {
    wallet: principal,
    name: (string-ascii 50),
    age: uint,
    education-level: (string-ascii 30),
    gpa: uint, ;; Stored as integer (e.g., 350 = 3.50 GPA)
    field-of-study: (string-ascii 100),
    financial-need-score: uint, ;; 1-10 scale
    academic-achievements: (string-ascii 400),
    community-service-hours: uint,
    scholarships-received: uint,
    total-scholarship-amount: uint,
    is-active: bool,
    created-at: uint
  }
)

(define-map scholarship-applications
  { application-id: uint }
  {
    student-id: uint,
    scholarship-id: uint,
    application-date: uint,
    essay: (string-ascii 1000),
    recommendation-score: uint,
    evaluation-score: uint,
    status: (string-ascii 20), ;; pending, approved, rejected, awarded
    award-date: (optional uint),
    created-at: uint
  }
)

(define-map scholarship-awards
  { student-id: uint, scholarship-id: uint }
  {
    award-amount: uint,
    award-date: uint,
    disbursement-schedule: (string-ascii 100),
    academic-requirements: (string-ascii 200),
    progress-reports-required: bool,
    renewal-eligible: bool
  }
)

(define-map student-by-wallet principal uint)
(define-map fund-contributions principal uint)

;; Public Functions

;; Create a new scholarship program
(define-public (create-scholarship
  (name (string-ascii 100))
  (description (string-ascii 500))
  (amount uint)
  (max-recipients uint)
  (eligibility-criteria (string-ascii 300))
  (application-deadline uint)
  (academic-year (string-ascii 20))
  (field-of-study (string-ascii 100)))
  (let
    (
      (scholarship-id (var-get next-scholarship-id))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (> max-recipients u0) ERR-INVALID-INPUT)
    (asserts! (> application-deadline block-height) ERR-INVALID-INPUT)

    (map-set scholarships
      { scholarship-id: scholarship-id }
      {
        name: name,
        description: description,
        amount: amount,
        max-recipients: max-recipients,
        current-recipients: u0,
        eligibility-criteria: eligibility-criteria,
        application-deadline: application-deadline,
        academic-year: academic-year,
        field-of-study: field-of-study,
        is-active: true,
        created-at: block-height
      }
    )

    (var-set next-scholarship-id (+ scholarship-id u1))

    (print { event: "scholarship-created", scholarship-id: scholarship-id, name: name, amount: amount })
    (ok scholarship-id)
  )
)

;; Register as a student
(define-public (register-student
  (name (string-ascii 50))
  (age uint)
  (education-level (string-ascii 30))
  (gpa uint)
  (field-of-study (string-ascii 100))
  (financial-need-score uint)
  (academic-achievements (string-ascii 400))
  (community-service-hours uint))
  (let
    (
      (student-id (var-get next-student-id))
      (caller tx-sender)
    )
    (asserts! (is-none (map-get? student-by-wallet caller)) ERR-ALREADY-EXISTS)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (>= age u16) ERR-INVALID-INPUT)
    (asserts! (<= age u30) ERR-INVALID-INPUT)
    (asserts! (>= gpa u0) ERR-INVALID-INPUT)
    (asserts! (<= gpa u400) ERR-INVALID-INPUT) ;; Max 4.00 GPA
    (asserts! (>= financial-need-score u1) ERR-INVALID-INPUT)
    (asserts! (<= financial-need-score u10) ERR-INVALID-INPUT)

    (map-set students
      { student-id: student-id }
      {
        wallet: caller,
        name: name,
        age: age,
        education-level: education-level,
        gpa: gpa,
        field-of-study: field-of-study,
        financial-need-score: financial-need-score,
        academic-achievements: academic-achievements,
        community-service-hours: community-service-hours,
        scholarships-received: u0,
        total-scholarship-amount: u0,
        is-active: true,
        created-at: block-height
      }
    )

    (map-set student-by-wallet caller student-id)
    (var-set next-student-id (+ student-id u1))

    (print { event: "student-registered", student-id: student-id, wallet: caller })
    (ok student-id)
  )
)

;; Apply for scholarship
(define-public (apply-for-scholarship
  (scholarship-id uint)
  (essay (string-ascii 1000))
  (recommendation-score uint))
  (let
    (
      (application-id (var-get next-application-id))
      (caller tx-sender)
      (student-id (unwrap! (map-get? student-by-wallet caller) ERR-NOT-FOUND))
      (scholarship-data (unwrap! (map-get? scholarships { scholarship-id: scholarship-id }) ERR-NOT-FOUND))
      (student-data (unwrap! (map-get? students { student-id: student-id }) ERR-NOT-FOUND))
    )
    (asserts! (get is-active scholarship-data) ERR-NOT-FOUND)
    (asserts! (get is-active student-data) ERR-NOT-FOUND)
    (asserts! (< block-height (get application-deadline scholarship-data)) ERR-APPLICATION-CLOSED)
    (asserts! (> (len essay) u100) ERR-INVALID-INPUT)
    (asserts! (>= recommendation-score u1) ERR-INVALID-INPUT)
    (asserts! (<= recommendation-score u10) ERR-INVALID-INPUT)

    (map-set scholarship-applications
      { application-id: application-id }
      {
        student-id: student-id,
        scholarship-id: scholarship-id,
        application-date: block-height,
        essay: essay,
        recommendation-score: recommendation-score,
        evaluation-score: u0,
        status: "pending",
        award-date: none,
        created-at: block-height
      }
    )

    (var-set next-application-id (+ application-id u1))

    (print { event: "scholarship-application-submitted", application-id: application-id, student-id: student-id, scholarship-id: scholarship-id })
    (ok application-id)
  )
)

;; Evaluate application
(define-public (evaluate-application (application-id uint) (evaluation-score uint) (status (string-ascii 20)))
  (let
    (
      (application-data (unwrap! (map-get? scholarship-applications { application-id: application-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status application-data) "pending") ERR-INVALID-INPUT)
    (asserts! (<= evaluation-score u100) ERR-INVALID-INPUT)
    (asserts! (or (is-eq status "approved") (is-eq status "rejected")) ERR-INVALID-INPUT)

    (map-set scholarship-applications
      { application-id: application-id }
      (merge application-data {
        evaluation-score: evaluation-score,
        status: status
      })
    )

    (print { event: "application-evaluated", application-id: application-id, status: status, score: evaluation-score })
    (ok true)
  )
)

;; Award scholarship
(define-public (award-scholarship
  (application-id uint)
  (disbursement-schedule (string-ascii 100))
  (academic-requirements (string-ascii 200))
  (progress-reports-required bool)
  (renewal-eligible bool))
  (let
    (
      (application-data (unwrap! (map-get? scholarship-applications { application-id: application-id }) ERR-NOT-FOUND))
      (scholarship-data (unwrap! (map-get? scholarships { scholarship-id: (get scholarship-id application-data) }) ERR-NOT-FOUND))
      (student-data (unwrap! (map-get? students { student-id: (get student-id application-data) }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status application-data) "approved") ERR-INVALID-INPUT)
    (asserts! (< (get current-recipients scholarship-data) (get max-recipients scholarship-data)) ERR-ALREADY-AWARDED)
    (asserts! (>= (var-get total-fund-balance) (get amount scholarship-data)) ERR-INSUFFICIENT-FUNDS)

    ;; Update application status
    (map-set scholarship-applications
      { application-id: application-id }
      (merge application-data {
        status: "awarded",
        award-date: (some block-height)
      })
    )

    ;; Create scholarship award record
    (map-set scholarship-awards
      { student-id: (get student-id application-data), scholarship-id: (get scholarship-id application-data) }
      {
        award-amount: (get amount scholarship-data),
        award-date: block-height,
        disbursement-schedule: disbursement-schedule,
        academic-requirements: academic-requirements,
        progress-reports-required: progress-reports-required,
        renewal-eligible: renewal-eligible
      }
    )

    ;; Update scholarship recipient count
    (map-set scholarships
      { scholarship-id: (get scholarship-id application-data) }
      (merge scholarship-data { current-recipients: (+ (get current-recipients scholarship-data) u1) })
    )

    ;; Update student scholarship stats
    (map-set students
      { student-id: (get student-id application-data) }
      (merge student-data {
        scholarships-received: (+ (get scholarships-received student-data) u1),
        total-scholarship-amount: (+ (get total-scholarship-amount student-data) (get amount scholarship-data))
      })
    )

    ;; Deduct from fund balance
    (var-set total-fund-balance (- (var-get total-fund-balance) (get amount scholarship-data)))

    (print { event: "scholarship-awarded", application-id: application-id, student-id: (get student-id application-data), amount: (get amount scholarship-data) })
    (ok true)
  )
)

;; Contribute to scholarship fund
(define-public (contribute-to-fund (amount uint))
  (let
    (
      (caller tx-sender)
      (current-contribution (default-to u0 (map-get? fund-contributions caller)))
    )
    (asserts! (> amount u0) ERR-INVALID-INPUT)

    ;; Update contributor record
    (map-set fund-contributions caller (+ current-contribution amount))

    ;; Update total fund balance
    (var-set total-fund-balance (+ (var-get total-fund-balance) amount))

    (print { event: "fund-contribution", contributor: caller, amount: amount, total-balance: (var-get total-fund-balance) })
    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-scholarship (scholarship-id uint))
  (map-get? scholarships { scholarship-id: scholarship-id })
)

(define-read-only (get-student (student-id uint))
  (map-get? students { student-id: student-id })
)

(define-read-only (get-student-by-wallet (wallet principal))
  (match (map-get? student-by-wallet wallet)
    student-id (map-get? students { student-id: student-id })
    none
  )
)

(define-read-only (get-application (application-id uint))
  (map-get? scholarship-applications { application-id: application-id })
)

(define-read-only (get-scholarship-award (student-id uint) (scholarship-id uint))
  (map-get? scholarship-awards { student-id: student-id, scholarship-id: scholarship-id })
)

(define-read-only (get-fund-balance)
  (var-get total-fund-balance)
)

(define-read-only (get-contributor-amount (contributor principal))
  (default-to u0 (map-get? fund-contributions contributor))
)
