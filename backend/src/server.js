const app = require('./app');
const env = require('./config/env');
const { connectDB } = require('./config/db');
const { ensureAdminAccount } = require('./controllers/authController');
const { runInventoryMigration } = require('./scripts/migrateInventory');
const { runApprovalMigration } = require('./scripts/migrateApproval');

async function startServer() {
  try {
    await connectDB();
    console.log(`[WaterFix] Connected to MongoDB at ${env.mongoUri}`);

    await ensureAdminAccount();
    console.log(`[WaterFix] Verified administrator account (${env.adminEmail})`);

    await runInventoryMigration();
    console.log('[WaterFix] Supplier company inventory models verified');

    await runApprovalMigration();
    console.log('[WaterFix] Pre-existing accounts approval status verified');

    app.listen(env.port, '0.0.0.0', () => {
      console.log(`[WaterFix] Backend API server running on http://0.0.0.0:${env.port}`);
    });
  } catch (err) {
    console.error('[WaterFix] Failed to start server:', err.message);
    process.exit(1);
  }
}

startServer();
