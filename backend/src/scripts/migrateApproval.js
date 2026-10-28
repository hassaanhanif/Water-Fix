const User = require('../models/User');
const SupplierProfile = require('../models/SupplierProfile');

/**
 * Migration ensuring all pre-existing accounts maintain approved status and verified email,
 * so they are never locked out or forced through CNIC review.
 */
async function runApprovalMigration() {
  try {
    // 1. Update any users missing approvalStatus
    const userResult = await User.updateMany(
      {
        $or: [
          { approvalStatus: { $exists: false } },
          { approvalStatus: null },
          { approvalStatus: '' },
        ],
      },
      {
        $set: {
          emailVerified: true,
          approvalStatus: 'approved',
          approvedAt: new Date(),
          approvedByName: 'System Migration (Pre-existing account)',
        },
      }
    );

    // 2. Explicitly safeguard known pre-existing accounts
    const legacyEmails = [
      'admin@waterfix.pk',
      'hassaanhanif655@gmail.com',
      'ashhadfawad05@gmail.com',
      'irtaza@gmail.com',
      'ahmad@gmail.com',
    ];

    await User.updateMany(
      { email: { $in: legacyEmails } },
      {
        $set: {
          emailVerified: true,
          approvalStatus: 'approved',
        },
      }
    );

    // 3. Update any supplier profiles missing approvalStatus
    const supplierResult = await SupplierProfile.updateMany(
      {
        $or: [
          { approvalStatus: { $exists: false } },
          { approvalStatus: null },
          { approvalStatus: '' },
        ],
      },
      {
        $set: {
          approvalStatus: 'approved',
          approvedAt: new Date(),
          approvedByName: 'System Migration (Pre-existing account)',
        },
      }
    );

    // Also ensure supplier profiles matching legacy user IDs are approved
    const legacyUsers = await User.find({ email: { $in: legacyEmails } });
    if (legacyUsers.length > 0) {
      const legacyUserIds = legacyUsers.map((u) => u._id);
      await SupplierProfile.updateMany(
        { userId: { $in: legacyUserIds } },
        {
          $set: {
            approvalStatus: 'approved',
          },
        }
      );
    }

    if (userResult.modifiedCount > 0 || supplierResult.modifiedCount > 0) {
      console.log(
        `[Migration] Grandfathered ${userResult.modifiedCount} pre-existing users and ${supplierResult.modifiedCount} suppliers as approved.`
      );
    }
  } catch (err) {
    console.error('[Migration] Approval migration error:', err.message);
  }
}

module.exports = { runApprovalMigration };
