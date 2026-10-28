const Review = require('../models/Review');
const Booking = require('../models/Booking');
const SupplierProfile = require('../models/SupplierProfile');

exports.createReview = async (req, res, next) => {
  try {
    if (req.user && req.user.isLocked) {
      return res.status(403).json({
        success: false,
        code: 'ACCOUNT_LOCKED',
        message: `Your customer account is locked${
          req.user.lockReason ? ` (${req.user.lockReason})` : ''
        }.`,
      });
    }

    const { bookingId, rating, tags, comment } = req.body;

    if (!bookingId) {
      return res.status(400).json({
        success: false,
        message: 'Booking ID is required to submit a review.',
      });
    }

    const numericRating = Number(rating);
    if (!numericRating || numericRating < 1 || numericRating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Please select a star rating between 1 and 5.',
      });
    }

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found.',
      });
    }

    if (booking.customerId.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'You can only review your own bookings.',
      });
    }

    if (booking.status !== 'delivered') {
      return res.status(400).json({
        success: false,
        message: 'Reviews can only be submitted for completed deliveries.',
      });
    }

    const existingReview = await Review.findOne({ bookingId: booking._id });
    if (existingReview || booking.isReviewed) {
      return res.status(409).json({
        success: false,
        message: 'You have already submitted a review for this delivery.',
      });
    }

    const review = await Review.create({
      bookingId: booking._id,
      customerId: req.user._id,
      customerName: req.user.name,
      supplierId: booking.supplierId,
      rating: numericRating,
      tags: Array.isArray(tags) ? tags : [],
      comment: comment ? comment.trim() : '',
    });

    booking.isReviewed = true;
    booking.reviewRating = numericRating;
    await booking.save();

    // Update supplier rating average and review count from real database records
    const allReviews = await Review.find({ supplierId: booking.supplierId });
    const count = allReviews.length;
    const sum = allReviews.reduce((acc, r) => acc + r.rating, 0);
    const avg = count > 0 ? Math.round((sum / count) * 10) / 10 : 0;

    await SupplierProfile.findByIdAndUpdate(booking.supplierId, {
      $set: {
        ratingAverage: avg,
        reviewCount: count,
      },
    });

    res.status(201).json({
      success: true,
      message: 'Thank you for reviewing your delivery!',
      data: review,
    });
  } catch (err) {
    next(err);
  }
};
