# Zero Food Waste - Donation Flow Testing Guide

This comprehensive test suite validates all donation delivery types and admin verification processes in the Zero Food Waste platform.

## 🧪 Test Suite Overview

### Test Files

- `test_donation_flows.js` - Complete end-to-end flow testing
- `test_individual_delivery_types.js` - Individual delivery type testing
- `test_delivery_verification.js` - Admin verification and management testing

## 🚀 Quick Start

### Prerequisites

1. Ensure your backend server is running on `http://localhost:3001`
2. Ensure your database has test users:
   - Admin: `admin@careconnect.com` / `admin123`
   - Donor: `donor@test.com` / `donor123`
   - Volunteer: `volunteer@test.com` / `volunteer123`
   - Delivery Person: `delivery@test.com` / `delivery123`

### Installation

```bash
npm install
```

## 📋 Test Commands

### Complete Flow Testing

```bash
# Test all delivery types end-to-end
npm run test:all

# Test individual delivery types
npm run test:individual

# Test admin verification processes
npm run test:verification-all

# Run complete test suite
npm run test:complete
```

### Individual Delivery Type Testing

```bash
# Test Self Delivery only
npm run test:self

# Test Volunteer Delivery only
npm run test:volunteer

# Test Paid Delivery only
npm run test:paid

# Test Admin verification only
npm run test:admin

# Test Payment flow only
npm run test:payment

# Test Delivery offers only
npm run test:offers
```

### Admin Verification Testing

```bash
# Test donation verification flow
npm run test:verification

# Test delivery management
npm run test:management

# Test volunteer delivery verification
npm run test:volunteer-verification

# Test paid delivery verification
npm run test:paid-verification
```

## 🔍 Test Scenarios

### 1. Self Delivery Flow

- ✅ Donation creation with "Self delivery" option
- ✅ Fixed location assignment (Care Connect office)
- ✅ No payment required
- ✅ Admin verification
- ✅ Status updates

### 2. Volunteer Delivery Flow

- ✅ Donation creation with "Volunteer Delivery" option
- ✅ Distance calculation
- ✅ Admin verification
- ✅ Volunteer sees available deliveries
- ✅ Volunteer creates offer
- ✅ Donor approves offer
- ✅ Points system tracking

### 3. Paid Delivery Flow

- ✅ Donation creation with "Paid Delivery" option
- ✅ Distance-based pricing calculation
- ✅ Payment processing (Stripe integration)
- ✅ Admin verification
- ✅ Delivery person sees available deliveries
- ✅ Delivery person creates offer
- ✅ Donor approves offer
- ✅ Commission tracking (10% platform, 90% delivery person)

### 4. Admin Verification Flow

- ✅ Pending donations retrieval
- ✅ Donation verification with notes
- ✅ Status updates
- ✅ Email notifications
- ✅ Delivery assignment triggers

### 5. Delivery Management Flow

- ✅ All deliveries overview
- ✅ Delivery statistics
- ✅ Payout management
- ✅ Personnel management
- ✅ Analytics dashboard

## 📊 Test Data

### Test Donations

Each test creates specific donations for different delivery types:

**Self Delivery:**

- Type: Food (Fruits & Vegetables)
- Quantity: 5 kg
- Location: Fixed office coordinates
- Cost: Free

**Volunteer Delivery:**

- Type: Clothes
- Quantity: 10 items
- Location: Variable coordinates
- Cost: Free (volunteer service)

**Paid Delivery:**

- Type: Medicine
- Quantity: 3 units
- Location: Variable coordinates
- Cost: Distance-based pricing

## 🔧 Test Configuration

### Environment Variables

- `BASE_URL`: Backend API URL (default: http://localhost:3001)
- `ADMIN_EMAIL`: Admin user email
- `DONOR_EMAIL`: Donor user email
- `VOLUNTEER_EMAIL`: Volunteer user email
- `DELIVERY_EMAIL`: Delivery person email

### Test Images

- Tests create temporary image files for donation verification
- Images are automatically cleaned up after tests

## 📈 Expected Results

### Successful Test Output

```
✅ [timestamp] Authenticated: admin@careconnect.com
✅ [timestamp] Authenticated: donor@test.com
✅ [timestamp] Self delivery donation created successfully
✅ [timestamp] Donation verified successfully
✅ [timestamp] Self delivery flow completed successfully
```

### Test Summary

```
=== TEST SUMMARY ===

SELF DELIVERY:
  ✅ Donation ID: 507f1f77bcf86cd799439011
  ✅ verification
  ✅ status_check

VOLUNTEER DELIVERY:
  ✅ Donation ID: 507f1f77bcf86cd799439012
  ✅ verification
  ✅ available_deliveries
  ✅ create_offer
  ✅ approve_offer

PAID DELIVERY:
  ✅ Donation ID: 507f1f77bcf86cd799439013
  ✅ verification
  ✅ available_deliveries
  ✅ create_offer
  ✅ approve_offer

Overall Success Rate: 100.0% (3/3)
```

## 🐛 Troubleshooting

### Common Issues

1. **Authentication Failed**

   - Ensure test users exist in database
   - Check user credentials
   - Verify backend is running

2. **Donation Creation Failed**

   - Check image upload functionality
   - Verify donation validation rules
   - Check database connection

3. **Verification Failed**

   - Ensure admin user has proper permissions
   - Check verification endpoint
   - Verify donation exists

4. **Delivery Offers Failed**
   - Check volunteer/delivery person authentication
   - Verify available deliveries endpoint
   - Check offer creation logic

### Debug Mode

Add `console.log` statements in test files to debug specific issues:

```javascript
// In test files
console.log("Response data:", response.data);
console.log("Request data:", requestData);
```

## 📝 Test Reports

### Coverage

- ✅ Donation creation (all types)
- ✅ Admin verification
- ✅ Delivery assignment
- ✅ Payment processing
- ✅ Status tracking
- ✅ Email notifications
- ✅ Analytics and reporting

### Performance

- Tests run in parallel where possible
- Image cleanup after each test
- Database state verification
- Error handling and reporting

## 🔄 Continuous Testing

### Automated Testing

```bash
# Run tests in watch mode (if using nodemon)
nodemon test_donation_flows.js

# Run specific test in loop
while true; do npm run test:self; sleep 30; done
```

### Integration with CI/CD

Add to your CI pipeline:

```yaml
- name: Run Donation Flow Tests
  run: |
    npm install
    npm run test:complete
```

## 📞 Support

For issues with the test suite:

1. Check the troubleshooting section
2. Review test logs for specific errors
3. Verify backend API endpoints
4. Check database connectivity
5. Ensure all test users exist

## 🎯 Next Steps

After running tests:

1. Review test results
2. Fix any failing tests
3. Update test data if needed
4. Add new test scenarios
5. Document any new features

---

**Happy Testing! 🚀**
