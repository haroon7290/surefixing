const express = require('express');
const Kyc = require('../models/Kyc');
const User = require('../models/User');
const { authRequired } = require('../middleware/auth');
const upload = require('../middleware/upload');

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
  async (req, res) => {
    const { fullName, idType, idNumber } = req.body;
    if (!fullName || !idType || !idNumber) {
      return res.status(400).json({ error: 'fullName, idType, idNumber required' });
    }
    const files = req.files || {};
    const data = {
      user: req.user._id,
      fullName,
      idType,
      idNumber,
      idFrontImage: files.idFront?.[0]?.filename || '',
      idBackImage: files.idBack?.[0]?.filename || '',
      selfieImage: files.selfie?.[0]?.filename || '',
      status: 'pending',
      rejectionReason: ''
    };
    const kyc = await Kyc.findOneAndUpdate({ user: req.user._id }, data, {
      upsert: true,
      new: true
    });
    req.user.kycStatus = 'pending';
    await req.user.save();
    res.status(201).json(kyc);
  }
);

module.exports = router;
