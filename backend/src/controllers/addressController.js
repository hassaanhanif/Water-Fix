const DeliveryAddress = require('../models/DeliveryAddress');

exports.getAddresses = async (req, res, next) => {
  try {
    const addresses = await DeliveryAddress.find({ userId: req.user._id }).sort({
      isDefault: -1,
      createdAt: -1,
    });
    res.json({ success: true, data: addresses });
  } catch (err) {
    next(err);
  }
};

exports.createAddress = async (req, res, next) => {
  try {
    const { label, addressLine, area, city, lat, lng, hasAccurateCoordinates, isDefault } = req.body;
    if (!addressLine || !addressLine.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Address line is required.',
      });
    }

    if (isDefault) {
      await DeliveryAddress.updateMany({ userId: req.user._id }, { $set: { isDefault: false } });
    }

    const count = await DeliveryAddress.countDocuments({ userId: req.user._id });
    const address = await DeliveryAddress.create({
      userId: req.user._id,
      label: label || 'Home',
      addressLine: addressLine.trim(),
      area: area || '',
      city: city || 'Islamabad',
      lat: typeof lat === 'number' ? lat : 33.6938,
      lng: typeof lng === 'number' ? lng : 73.0169,
      hasAccurateCoordinates:
        hasAccurateCoordinates !== undefined ? Boolean(hasAccurateCoordinates) : true,
      isDefault: isDefault || count === 0,
    });

    res.status(201).json({
      success: true,
      message: 'Delivery address saved.',
      data: address,
    });
  } catch (err) {
    next(err);
  }
};

exports.updateAddress = async (req, res, next) => {
  try {
    const address = await DeliveryAddress.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });
    if (!address) {
      return res.status(404).json({ success: false, message: 'Address not found.' });
    }

    const { label, addressLine, area, city, lat, lng, hasAccurateCoordinates, isDefault } = req.body;
    if (isDefault) {
      await DeliveryAddress.updateMany({ userId: req.user._id }, { $set: { isDefault: false } });
      address.isDefault = true;
    }
    if (label) address.label = label;
    if (addressLine) address.addressLine = addressLine.trim();
    if (area !== undefined) address.area = area;
    if (city) address.city = city;
    if (typeof lat === 'number') address.lat = lat;
    if (typeof lng === 'number') address.lng = lng;
    if (hasAccurateCoordinates !== undefined) {
      address.hasAccurateCoordinates = Boolean(hasAccurateCoordinates);
    }

    await address.save();
    res.json({ success: true, data: address });
  } catch (err) {
    next(err);
  }
};

exports.deleteAddress = async (req, res, next) => {
  try {
    const deleted = await DeliveryAddress.findOneAndDelete({
      _id: req.params.id,
      userId: req.user._id,
    });
    if (!deleted) {
      return res.status(404).json({ success: false, message: 'Address not found.' });
    }
    res.json({ success: true, message: 'Address removed.' });
  } catch (err) {
    next(err);
  }
};
