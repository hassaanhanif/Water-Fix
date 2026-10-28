function errorHandler(err, req, res, next) {
  const statusCode = err.statusCode || 500;
  const message = err.message || 'An unexpected server error occurred.';

  if (process.env.NODE_ENV !== 'test' && statusCode === 500) {
    console.error('[WaterFix Backend Error]:', err.message);
  }

  res.status(statusCode).json({
    success: false,
    message,
    ...(err.errors ? { errors: err.errors } : {}),
  });
}

module.exports = errorHandler;
