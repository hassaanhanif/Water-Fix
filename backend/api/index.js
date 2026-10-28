const app = require('../src/app');
const { connectDB } = require('../src/config/db');
const { ensureAdminAccount } = require('../src/controllers/authController');

let isInitialized = false;

module.exports = async (req, res) => {
  if (!isInitialized) {
    try {
      await connectDB();
      await ensureAdminAccount();
      isInitialized = true;
    } catch (err) {
      console.error('[WaterFix Vercel] DB Connection Error:', err);
      return res.status(500).json({
        success: false,
        message: 'Database connection failed: ' + err.message,
      });
    }
  }

  return app(req, res);
};
