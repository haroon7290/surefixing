const express = require('express');
const { body } = require('express-validator');
const Kyc = require('../models/Kyc');
const { authRequired } = require('../middleware/auth');
const { validate, discardUploads } = require('../middleware/validate');
const upload = require('../middleware/upload');
const realtime = require('../utils/realtime');
const { badRequest } = require('../utils/http');

const router = express.Router();

router.get('/me', authRequired, async (req, res) => {
  const kyc = await Kyc.findOne({ user: req.user._id });
  res.json(kyc || null);
});

router.post(
  '/',
  authRequired,
  upload.fields([
    { name: 'idFront', maxCount: 1 },
    { name: 'idBack', maxCount: 1 },
    { name: 'selfie', maxCount: 1 }
  ]),
  [
    body('fullName').trim().isLength({ min: 3, max: 100 }).withMessage('Enter your full legal name'),
    body('idType').isIn(['cnic', 'passport', 'driver_license']).withMessage('Choose a valid ID type'),
    body('idNumber').trim().isLength({ min: 4, max: 40 }).withMessage('Enter a valid ID number')
  ],
  validate,
  async (req, res) => {
    const existing = await Kyc.findOne({ user: req.user._id });
    if (existing && existing.status === 'approved') {
      discardUploads(req);
      throw badRequest('Your verification is already approved');
    }
    const files = req.files || {};
    const front = files.idFront?.[0]?.filename || existing?.idFrontImage || '';
    const selfie = files.selfie?.[0]?.filename || existing?.selfieImage || '';
    if (!front || !selfie) {
      discardUploads(req);
      throw badRequest('Add a photo of the front of your ID and a selfie');
    }
    const { fullName, idType, idNumber } = req.body;
    const kyc = await Kyc.findOneAndUpdate(
      { user: req.user._id },
      {
        user: req.user._id,
        fullName,
        idType,
        idNumber,
        idFrontImage: front,
        idBackImage: files.idBack?.[0]?.filename || existing?.idBackImage || '',
        selfieImage: selfie,
        status: 'pending',
        rejectionReason: ''
      },
      { upsert: true, new: true }
    );
    req.user.kycStatus = 'pending';
    await req.user.save();
    realtime.emitRole('admin', 'kyc:new', { kycId: kyc._id, name: req.user.name, role: req.user.role });
    res.status(201).json(kyc);
  }
);

module.exports = router;
