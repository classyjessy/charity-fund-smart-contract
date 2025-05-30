# Transparent Charity Platform

A decentralized charitable giving platform built on the Stacks blockchain using Clarity smart contracts. This platform enables transparent, accountable charitable donations with comprehensive tracking, multi-charity support, and automated fee management.

## Features

### Core Functionality
- **Transparent Donations**: All donations are recorded on-chain with full transparency
- **Multi-Charity Support**: Multiple charitable organizations can register and operate on the platform
- **Donation Tracking**: Comprehensive tracking of all donations, donors, and charity relationships
- **Automated Fee Management**: Configurable platform fees with automatic distribution
- **Fund Withdrawal**: Secure withdrawal system for registered charities
- **Ownership Management**: Transfer charity ownership with proper authorization

### Security & Access Control
- **Role-Based Access**: Separate permissions for administrators, charity owners, and donors
- **Input Validation**: Comprehensive validation for all user inputs
- **Authorization Checks**: Strict authorization controls for sensitive operations
- **Operational Status**: Charities can be activated/deactivated as needed

## Contract Overview

### Constants
- **Platform Fee**: Default 2.5% (250 basis points), maximum 10%
- **Text Limits**: 
  - Charity names: 50 characters
  - Descriptions: 200 characters
  - Donation messages: 100 characters
- **Error Codes**: Comprehensive error handling with specific error codes

### Data Structures

#### Charitable Organizations
```clarity
{
  organization-name: string-ascii,
  mission-description: string-ascii,
  authorized-beneficiary: principal,
  cumulative-donations-received: uint,
  total-funds-withdrawn: uint,
  operational-status: bool,
  registration-block-height: uint,
  last-activity-timestamp: uint
}
```

#### Donation Transactions
```clarity
{
  contribution-amount: uint,
  transaction-block-height: uint,
  donor-message: optional string-ascii,
  platform-fee-deducted: uint,
  net-charity-amount: uint
}
```

## Getting Started

### Prerequisites
- Stacks blockchain node or access to Stacks testnet/mainnet
- Clarity CLI or Stacks development environment
- STX tokens for transactions

### Deployment
1. Deploy the contract to the Stacks blockchain
2. The deployer automatically becomes the contract administrator
3. Platform analytics are initialized with zero values

## Usage Guide

### For Charity Organizations

#### 1. Register Your Charity
```clarity
(contract-call? .charity-platform register-charitable-organization 
  "My Charity Name" 
  "Description of charity mission and goals")
```

#### 2. Update Charity Information
```clarity
(contract-call? .charity-platform update-charity-information 
  u1 ;; organization-id
  "Updated Charity Name" 
  "Updated mission description")
```

#### 3. Withdraw Funds
```clarity
(contract-call? .charity-platform withdraw-charity-funds 
  u1 ;; organization-id
  u1000000) ;; amount in microSTX
```

#### 4. Transfer Ownership
```clarity
(contract-call? .charity-platform transfer-charity-ownership 
  u1 ;; organization-id
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7) ;; new-owner-address
```

### For Donors

#### Make a Donation
```clarity
(contract-call? .charity-platform contribute-to-charity 
  u1 ;; target-organization-id
  u5000000 ;; donation amount in microSTX
  (some "Thank you for your great work!")) ;; optional message
```

### For Administrators

#### Update Platform Fee
```clarity
(contract-call? .charity-platform update-platform-fee-percentage 
  u300) ;; 3% in basis points
```

#### Withdraw Platform Revenue
```clarity
(contract-call? .charity-platform withdraw-platform-revenue 
  u1000000) ;; amount in microSTX
```

## Query Functions

### Get Charity Details
```clarity
(contract-call? .charity-platform get-charity-details u1)
```

### Check Available Funds
```clarity
(contract-call? .charity-platform get-available-charity-funds u1)
```

### Get Donation History
```clarity
(contract-call? .charity-platform get-donation-transaction-info 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 ;; donor-address
  u1 ;; organization-id
  u1) ;; transaction-id
```

### Get Platform Statistics
```clarity
(contract-call? .charity-platform get-platform-operational-metrics)
```

### Get Donor-Charity Relationship
```clarity
(contract-call? .charity-platform get-donor-charity-relationship 
  u1 ;; organization-id
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7) ;; donor-address
```

## Error Codes

### Access Control Errors
- `u100`: Unauthorized access
- `u101`: Charity owner only
- `u102`: Admin privileges required

### Charity Management Errors
- `u200`: Charity not found
- `u201`: Charity already exists
- `u202`: Charity deactivated
- `u203`: Charity creation failed

### Financial Transaction Errors
- `u300`: Insufficient balance
- `u301`: Invalid donation amount
- `u302`: Withdrawal limit exceeded
- `u303`: Transfer execution failed
- `u304`: Platform fee calculation error

### Input Validation Errors
- `u400`: Empty charity name
- `u401`: Empty description
- `u402`: Invalid recipient address
- `u403`: Message too long
- `u404`: Invalid organization ID

## Security Considerations

1. **Authorization**: All sensitive functions require proper authorization
2. **Input Validation**: All inputs are validated before processing
3. **Balance Checks**: Sufficient balance verification before transfers
4. **Operational Status**: Inactive charities cannot receive donations
5. **Fee Calculation**: Platform fees are calculated and distributed automatically

## Analytics & Tracking

The platform maintains comprehensive analytics including:
- Total registered charities
- Total donation transactions
- Platform lifetime revenue
- Total donation volume
- Individual donor-charity relationships
- Charity activity timestamps