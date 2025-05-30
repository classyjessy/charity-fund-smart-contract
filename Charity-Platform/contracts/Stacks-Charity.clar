;; Transparent Charity Platform Contract
;; A decentralized platform enabling transparent charitable giving with accountability,
;; multi-charity support, donation tracking, and automated fee management for sustainable operations

;; ===== CONTRACT CONSTANTS =====

;; Access Control & Authorization
(define-constant contract-administrator tx-sender)
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-CHARITY-OWNER-ONLY (err u101))
(define-constant ERR-ADMIN-PRIVILEGES-REQUIRED (err u102))

;; Charity Management Errors
(define-constant ERR-CHARITY-NOT-FOUND (err u200))
(define-constant ERR-CHARITY-ALREADY-EXISTS (err u201))
(define-constant ERR-CHARITY-DEACTIVATED (err u202))
(define-constant ERR-CHARITY-CREATION-FAILED (err u203))

;; Financial Transaction Errors
(define-constant ERR-INSUFFICIENT-BALANCE (err u300))
(define-constant ERR-INVALID-DONATION-AMOUNT (err u301))
(define-constant ERR-WITHDRAWAL-LIMIT-EXCEEDED (err u302))
(define-constant ERR-TRANSFER-EXECUTION-FAILED (err u303))
(define-constant ERR-PLATFORM-FEE-CALCULATION-ERROR (err u304))

;; Input Validation Errors
(define-constant ERR-EMPTY-CHARITY-NAME (err u400))
(define-constant ERR-EMPTY-DESCRIPTION (err u401))
(define-constant ERR-INVALID-RECIPIENT-ADDRESS (err u402))
(define-constant ERR-MESSAGE-TOO-LONG (err u403))
(define-constant ERR-INVALID-ORGANIZATION-ID (err u404))

;; Business Logic Constants
(define-constant maximum-charity-name-length u50)
(define-constant maximum-description-length u200)
(define-constant maximum-donation-message-length u100)
(define-constant default-platform-fee-basis-points u250) ;; 2.5%
(define-constant maximum-platform-fee-basis-points u1000) ;; 10%
(define-constant basis-points-divisor u10000)

;; ===== DATA STRUCTURES =====

;; Primary charity registry with comprehensive metadata
(define-map charitable-organizations
  { organization-identifier: uint }
  {
    organization-name: (string-ascii 50),
    mission-description: (string-ascii 200),
    authorized-beneficiary: principal,
    cumulative-donations-received: uint,
    total-funds-withdrawn: uint,
    operational-status: bool,
    registration-block-height: uint,
    last-activity-timestamp: uint
  }
)

;; Detailed donation transaction records
(define-map donation-transaction-history
  { benefactor-address: principal, target-organization-id: uint, transaction-sequence-number: uint }
  {
    contribution-amount: uint,
    transaction-block-height: uint,
    donor-message: (optional (string-ascii 100)),
    platform-fee-deducted: uint,
    net-charity-amount: uint
  }
)

;; Aggregated donor statistics per charity
(define-map benefactor-charity-relationships
  { organization-identifier: uint, donor-principal: principal }
  { 
    lifetime-contribution-total: uint, 
    number-of-donations-made: uint,
    first-donation-timestamp: uint,
    most-recent-donation-timestamp: uint
  }
)

;; Contract-wide operational metrics
(define-map platform-analytics
  { metric-identifier: (string-ascii 20) }
  { metric-value: uint }
)

;; ===== STATE VARIABLES =====

(define-data-var next-organization-id-sequence uint u1)
(define-data-var next-transaction-id-sequence uint u1)
(define-data-var registered-charities-count uint u0)
(define-data-var total-platform-transactions uint u0)
(define-data-var current-platform-fee-percentage uint default-platform-fee-basis-points)
(define-data-var platform-total-revenue uint u0)
(define-data-var contract-deployment-timestamp uint u0)

;; ===== INITIALIZATION =====

;; Initialize contract state upon deployment
(begin
  (var-set contract-deployment-timestamp stacks-block-height)
  (map-set platform-analytics { metric-identifier: "total-volume" } { metric-value: u0 })
  (map-set platform-analytics { metric-identifier: "active-charities" } { metric-value: u0 })
)

;; ===== VALIDATION HELPER FUNCTIONS =====

;; Validate organization ID exists and is within valid range
(define-private (validate-organization-id (organization-id uint))
  (and 
    (> organization-id u0)
    (< organization-id (var-get next-organization-id-sequence))
  )
)

;; Validate donation message length if provided
(define-private (validate-donation-message (message (optional (string-ascii 100))))
  (match message
    msg (<= (len msg) maximum-donation-message-length)
    true
  )
)

;; ===== READ-ONLY QUERY FUNCTIONS =====

;; Retrieve comprehensive charity information
(define-read-only (get-charity-details (organization-id uint))
  (if (validate-organization-id organization-id)
    (map-get? charitable-organizations { organization-identifier: organization-id })
    none
  )
)

;; Calculate available charity balance for withdrawals
(define-read-only (get-available-charity-funds (organization-id uint))
  (if (validate-organization-id organization-id)
    (match (map-get? charitable-organizations { organization-identifier: organization-id })
      charity-information 
      (ok (- (get cumulative-donations-received charity-information) 
             (get total-funds-withdrawn charity-information)))
      ERR-CHARITY-NOT-FOUND
    )
    ERR-INVALID-ORGANIZATION-ID
  )
)

;; Retrieve specific donation transaction details
(define-read-only (get-donation-transaction-info (donor-address principal) (organization-id uint) (transaction-id uint))
  (if (validate-organization-id organization-id)
    (map-get? donation-transaction-history 
      { benefactor-address: donor-address, target-organization-id: organization-id, transaction-sequence-number: transaction-id })
    none
  )
)

;; Get donor's relationship statistics with specific charity
(define-read-only (get-donor-charity-relationship (organization-id uint) (donor-address principal))
  (if (validate-organization-id organization-id)
    (map-get? benefactor-charity-relationships 
      { organization-identifier: organization-id, donor-principal: donor-address })
    none
  )
)

;; Retrieve comprehensive platform statistics
(define-read-only (get-platform-operational-metrics)
  {
    total-registered-charities: (var-get registered-charities-count),
    total-donation-transactions: (var-get total-platform-transactions),
    current-fee-percentage: (var-get current-platform-fee-percentage),
    platform-lifetime-revenue: (var-get platform-total-revenue),
    contract-deployment-height: (var-get contract-deployment-timestamp)
  }
)

;; Verify charity ownership authorization
(define-read-only (verify-charity-ownership (organization-id uint) (potential-owner-address principal))
  (if (validate-organization-id organization-id)
    (match (map-get? charitable-organizations { organization-identifier: organization-id })
      charity-data (is-eq (get authorized-beneficiary charity-data) potential-owner-address)
      false
    )
    false
  )
)

;; Calculate platform fee for given donation amount
(define-read-only (calculate-platform-fee-amount (donation-amount uint))
  (/ (* donation-amount (var-get current-platform-fee-percentage)) basis-points-divisor)
)

;; Get charity operational status
(define-read-only (get-charity-operational-status (organization-id uint))
  (if (validate-organization-id organization-id)
    (match (map-get? charitable-organizations { organization-identifier: organization-id })
      charity-info (ok (get operational-status charity-info))
      ERR-CHARITY-NOT-FOUND
    )
    ERR-INVALID-ORGANIZATION-ID
  )
)

;; ===== CHARITY MANAGEMENT FUNCTIONS =====

;; Register new charitable organization
(define-public (register-charitable-organization 
  (organization-name (string-ascii 50)) 
  (mission-description (string-ascii 200)))
  (let 
    (
      (new-organization-id (var-get next-organization-id-sequence))
      (current-block-height stacks-block-height)
    )
    ;; Input validation
    (asserts! (> (len organization-name) u0) ERR-EMPTY-CHARITY-NAME)
    (asserts! (> (len mission-description) u0) ERR-EMPTY-DESCRIPTION)
    (asserts! (<= (len organization-name) maximum-charity-name-length) ERR-EMPTY-CHARITY-NAME)
    (asserts! (<= (len mission-description) maximum-description-length) ERR-EMPTY-DESCRIPTION)
    
    ;; Create charity organization record
    (map-set charitable-organizations
      { organization-identifier: new-organization-id }
      {
        organization-name: organization-name,
        mission-description: mission-description,
        authorized-beneficiary: tx-sender,
        cumulative-donations-received: u0,
        total-funds-withdrawn: u0,
        operational-status: true,
        registration-block-height: current-block-height,
        last-activity-timestamp: current-block-height
      }
    )
    
    ;; Update global state counters
    (var-set next-organization-id-sequence (+ new-organization-id u1))
    (var-set registered-charities-count (+ (var-get registered-charities-count) u1))
    
    ;; Update platform analytics
    (map-set platform-analytics 
      { metric-identifier: "active-charities" } 
      { metric-value: (+ 
        (default-to u0 (get metric-value (map-get? platform-analytics { metric-identifier: "active-charities" }))) 
        u1) })
    
    (ok new-organization-id)
  )
)

;; Update charity information (authorized beneficiary only)
(define-public (update-charity-information 
  (organization-id uint) 
  (new-organization-name (string-ascii 50)) 
  (new-mission-description (string-ascii 200)))
  (let
    (
      (validated-org-id (asserts! (validate-organization-id organization-id) ERR-INVALID-ORGANIZATION-ID))
      (charity-information (unwrap! (map-get? charitable-organizations { organization-identifier: organization-id }) ERR-CHARITY-NOT-FOUND))
      (current-block-height stacks-block-height)
    )
    
    ;; Authorization check
    (asserts! (is-eq tx-sender (get authorized-beneficiary charity-information)) ERR-CHARITY-OWNER-ONLY)
    
    ;; Input validation
    (asserts! (> (len new-organization-name) u0) ERR-EMPTY-CHARITY-NAME)
    (asserts! (> (len new-mission-description) u0) ERR-EMPTY-DESCRIPTION)
    (asserts! (<= (len new-organization-name) maximum-charity-name-length) ERR-EMPTY-CHARITY-NAME)
    (asserts! (<= (len new-mission-description) maximum-description-length) ERR-EMPTY-DESCRIPTION)
    
    ;; Update charity information
    (map-set charitable-organizations
      { organization-identifier: organization-id }
      (merge charity-information { 
        organization-name: new-organization-name, 
        mission-description: new-mission-description,
        last-activity-timestamp: current-block-height
      })
    )
    
    (ok true)
  )
)

;; Toggle charity operational status
(define-public (toggle-charity-operational-status (organization-id uint))
  (let
    (
      (validated-org-id (asserts! (validate-organization-id organization-id) ERR-INVALID-ORGANIZATION-ID))
      (charity-information (unwrap! (map-get? charitable-organizations { organization-identifier: organization-id }) ERR-CHARITY-NOT-FOUND))
      (new-operational-status (not (get operational-status charity-information)))
      (current-block-height stacks-block-height)
    )
    
    ;; Authorization check
    (asserts! (is-eq tx-sender (get authorized-beneficiary charity-information)) ERR-CHARITY-OWNER-ONLY)
    
    ;; Update operational status
    (map-set charitable-organizations
      { organization-identifier: organization-id }
      (merge charity-information { 
        operational-status: new-operational-status,
        last-activity-timestamp: current-block-height
      })
    )
    
    (ok new-operational-status)
  )
)

;; Transfer charity ownership to new beneficiary
(define-public (transfer-charity-ownership (organization-id uint) (new-authorized-beneficiary principal))
  (let
    (
      (validated-org-id (asserts! (validate-organization-id organization-id) ERR-INVALID-ORGANIZATION-ID))
      (charity-information (unwrap! (map-get? charitable-organizations { organization-identifier: organization-id }) ERR-CHARITY-NOT-FOUND))
      (current-block-height stacks-block-height)
    )
    
    ;; Authorization and validation checks
    (asserts! (is-eq tx-sender (get authorized-beneficiary charity-information)) ERR-CHARITY-OWNER-ONLY)
    (asserts! (not (is-eq tx-sender new-authorized-beneficiary)) ERR-INVALID-RECIPIENT-ADDRESS)
    
    ;; Transfer ownership
    (map-set charitable-organizations
      { organization-identifier: organization-id }
      (merge charity-information { 
        authorized-beneficiary: new-authorized-beneficiary,
        last-activity-timestamp: current-block-height
      })
    )
    
    (ok new-authorized-beneficiary)
  )
)

;; ===== DONATION PROCESSING FUNCTIONS =====

;; Process charitable donation with comprehensive tracking
(define-public (contribute-to-charity 
  (target-organization-id uint) 
  (donation-amount uint) 
  (donor-message (optional (string-ascii 100))))
  (let
    (
      (validated-org-id (asserts! (validate-organization-id target-organization-id) ERR-INVALID-ORGANIZATION-ID))
      (validated-message (asserts! (validate-donation-message donor-message) ERR-MESSAGE-TOO-LONG))
      (charity-information (unwrap! (map-get? charitable-organizations { organization-identifier: target-organization-id }) ERR-CHARITY-NOT-FOUND))
      (transaction-id (var-get next-transaction-id-sequence))
      (current-block-height stacks-block-height)
      (calculated-platform-fee (calculate-platform-fee-amount donation-amount))
      (net-charity-contribution (- donation-amount calculated-platform-fee))
    )
    
    ;; Comprehensive validation
    (asserts! (> donation-amount u0) ERR-INVALID-DONATION-AMOUNT)
    (asserts! (get operational-status charity-information) ERR-CHARITY-DEACTIVATED)
    
    ;; Execute STX transfer from donor to contract
    (try! (stx-transfer? donation-amount tx-sender (as-contract tx-sender)))
    
    ;; Record comprehensive donation transaction
    (map-set donation-transaction-history
      { benefactor-address: tx-sender, target-organization-id: target-organization-id, transaction-sequence-number: transaction-id }
      {
        contribution-amount: donation-amount,
        transaction-block-height: current-block-height,
        donor-message: donor-message,
        platform-fee-deducted: calculated-platform-fee,
        net-charity-amount: net-charity-contribution
      }
    )
    
    ;; Update charity cumulative donations
    (map-set charitable-organizations
      { organization-identifier: target-organization-id }
      (merge charity-information { 
        cumulative-donations-received: (+ (get cumulative-donations-received charity-information) net-charity-contribution),
        last-activity-timestamp: current-block-height
      })
    )
    
    ;; Update or create donor-charity relationship
    (match (map-get? benefactor-charity-relationships { organization-identifier: target-organization-id, donor-principal: tx-sender })
      existing-relationship
      (map-set benefactor-charity-relationships
        { organization-identifier: target-organization-id, donor-principal: tx-sender }
        {
          lifetime-contribution-total: (+ (get lifetime-contribution-total existing-relationship) net-charity-contribution),
          number-of-donations-made: (+ (get number-of-donations-made existing-relationship) u1),
          first-donation-timestamp: (get first-donation-timestamp existing-relationship),
          most-recent-donation-timestamp: current-block-height
        }
      )
      ;; Create new donor relationship
      (map-set benefactor-charity-relationships
        { organization-identifier: target-organization-id, donor-principal: tx-sender }
        {
          lifetime-contribution-total: net-charity-contribution,
          number-of-donations-made: u1,
          first-donation-timestamp: current-block-height,
          most-recent-donation-timestamp: current-block-height
        }
      )
    )
    
    ;; Update global state and analytics
    (var-set next-transaction-id-sequence (+ transaction-id u1))
    (var-set total-platform-transactions (+ (var-get total-platform-transactions) u1))
    (var-set platform-total-revenue (+ (var-get platform-total-revenue) calculated-platform-fee))
    
    ;; Update platform volume analytics
    (map-set platform-analytics 
      { metric-identifier: "total-volume" } 
      { metric-value: (+ 
        (default-to u0 (get metric-value (map-get? platform-analytics { metric-identifier: "total-volume" }))) 
        donation-amount) })
    
    ;; Transfer platform fee to administrator if applicable
    (if (> calculated-platform-fee u0)
      (try! (as-contract (stx-transfer? calculated-platform-fee tx-sender contract-administrator)))
      true
    )
    
    (ok { 
      transaction-identifier: transaction-id, 
      net-charity-amount: net-charity-contribution, 
      platform-fee-amount: calculated-platform-fee 
    })
  )
)

;; ===== FUND WITHDRAWAL FUNCTIONS =====

;; Withdraw available charity funds (authorized beneficiary only)
(define-public (withdraw-charity-funds (organization-id uint) (withdrawal-amount uint))
  (let
    (
      (validated-org-id (asserts! (validate-organization-id organization-id) ERR-INVALID-ORGANIZATION-ID))
      (charity-information (unwrap! (map-get? charitable-organizations { organization-identifier: organization-id }) ERR-CHARITY-NOT-FOUND))
      (available-balance (- (get cumulative-donations-received charity-information) (get total-funds-withdrawn charity-information)))
      (current-block-height stacks-block-height)
    )
    
    ;; Comprehensive authorization and validation
    (asserts! (is-eq tx-sender (get authorized-beneficiary charity-information)) ERR-CHARITY-OWNER-ONLY)
    (asserts! (get operational-status charity-information) ERR-CHARITY-DEACTIVATED)
    (asserts! (> withdrawal-amount u0) ERR-INVALID-DONATION-AMOUNT)
    (asserts! (<= withdrawal-amount available-balance) ERR-INSUFFICIENT-BALANCE)
    
    ;; Execute withdrawal transfer
    (try! (as-contract (stx-transfer? withdrawal-amount tx-sender (get authorized-beneficiary charity-information))))
    
    ;; Update charity withdrawal records
    (map-set charitable-organizations
      { organization-identifier: organization-id }
      (merge charity-information { 
        total-funds-withdrawn: (+ (get total-funds-withdrawn charity-information) withdrawal-amount),
        last-activity-timestamp: current-block-height
      })
    )
    
    (ok withdrawal-amount)
  )
)

;; ===== PLATFORM ADMINISTRATION FUNCTIONS =====

;; Update platform fee percentage (administrator only)
(define-public (update-platform-fee-percentage (new-fee-basis-points uint))
  (begin
    (asserts! (is-eq tx-sender contract-administrator) ERR-ADMIN-PRIVILEGES-REQUIRED)
    (asserts! (<= new-fee-basis-points maximum-platform-fee-basis-points) ERR-PLATFORM-FEE-CALCULATION-ERROR)
    
    (var-set current-platform-fee-percentage new-fee-basis-points)
    (ok new-fee-basis-points)
  )
)

;; Emergency platform revenue withdrawal (administrator only)
(define-public (withdraw-platform-revenue (withdrawal-amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-administrator) ERR-ADMIN-PRIVILEGES-REQUIRED)
    (asserts! (> withdrawal-amount u0) ERR-INVALID-DONATION-AMOUNT)
    
    (try! (as-contract (stx-transfer? withdrawal-amount tx-sender contract-administrator)))
    (ok withdrawal-amount)
  )
)