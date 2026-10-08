const express = require('express');
const catalog = require('../config/catalog');

const router = express.Router();

// Public: taxonomies the app needs before login (e.g. on the sign-up form).
router.get('/', (_req, res) => {
  res.json({
    serviceCategories: catalog.SERVICE_CATEGORIES,
    toolCategories: catalog.TOOL_CATEGORIES,
    urgencyLevels: catalog.URGENCY_LEVELS,
    toolConditions: catalog.TOOL_CONDITIONS,
    reportReasons: catalog.REPORT_REASONS
  });
});

module.exports = router;
