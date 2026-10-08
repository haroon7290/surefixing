// Demo data for presentations and local development.
//
//   npm run seed            seeds only if the database has no users
//   npm run seed -- --force wipes ALL SureFix collections and reseeds
//
// Every demo account uses the password "password123".
const mongoose = require('mongoose');
const config = require('../config');
const User = require('../models/User');
const Job = require('../models/Job');
const Tool = require('../models/Tool');
const Rental = require('../models/Rental');
const Message = require('../models/Message');
const Notification = require('../models/Notification');
const Kyc = require('../models/Kyc');
const Report = require('../models/Report');

const DAY = 24 * 3600 * 1000;
const HOUR = 3600 * 1000;
const ago = (ms) => new Date(Date.now() - ms);
const ahead = (ms) => new Date(Date.now() + ms);
const PASSWORD = 'password123';

async function run() {
  const force = process.argv.includes('--force') || process.argv.includes('--yes');
  await mongoose.connect(config.mongoUri);

  const existing = await User.countDocuments();
  if (existing > 0 && !force) {
    console.log(`Database already has ${existing} users — nothing seeded.`);
    console.log('To WIPE everything and load demo data, run:  npm run seed -- --force');
    await mongoose.disconnect();
    return;
  }

  console.log('Wiping SureFix collections…');
  await Promise.all(
    [User, Job, Tool, Rental, Message, Notification, Kyc, Report].map((M) => M.deleteMany({}))
  );

  const u = (o) => ({ password: PASSWORD, ...o });
  const [
    sara, bilal, ahmad, noor, usman, zainab, hamza, ayesha, farhan, imran, toolco, buildpro, admin
  ] = await User.create([
    u({ name: 'Sara Khan', email: 'client@demo.com', role: 'client', phone: '0300-1234501', city: 'Lahore' }),
    u({ name: 'Bilal Ahmed', email: 'client2@demo.com', role: 'client', phone: '0300-1234502', city: 'Karachi' }),
    u({
      name: 'Ahmad Raza', email: 'tech@demo.com', role: 'technician', phone: '0300-1234503', city: 'Lahore',
      headline: 'Licensed electrician & plumber', skills: ['plumbing', 'electrical'],
      bio: 'Licensed electrician with 8 years of residential experience. Neat work, fair quotes, and I clean up after myself.',
      rating: 4.6, ratingCount: 12, jobsCompleted: 14, jobsAssigned: 15, avgResponseMinutes: 22, responseSamples: 15,
      experienceYears: 8, hourlyRate: 1500, kycStatus: 'approved'
    }),
    u({
      name: 'Noor Fatima', email: 'tech2@demo.com', role: 'technician', phone: '0300-1234504', city: 'Lahore',
      headline: 'Carpenter & handywoman', skills: ['carpentry', 'general'],
      bio: 'Custom furniture repairs, cabinet fitting and all the small jobs around the house.',
      rating: 4.1, ratingCount: 6, jobsCompleted: 7, jobsAssigned: 9, avgResponseMinutes: 45, responseSamples: 9,
      experienceYears: 5, hourlyRate: 1200, kycStatus: 'approved'
    }),
    u({
      name: 'Usman Ali', email: 'tech3@demo.com', role: 'technician', phone: '0300-1234505', city: 'Lahore',
      headline: 'AC & appliance specialist', skills: ['hvac', 'appliance'],
      bio: 'Split AC installation, gas refills, inverter AC and fridge repairs. Certified by two major brands.',
      rating: 4.8, ratingCount: 21, jobsCompleted: 25, jobsAssigned: 26, avgResponseMinutes: 15, responseSamples: 26,
      experienceYears: 10, hourlyRate: 2000, kycStatus: 'approved'
    }),
    u({
      name: 'Zainab Hussain', email: 'tech4@demo.com', role: 'technician', phone: '0300-1234506', city: 'Islamabad',
      headline: 'Painter & tiling expert', skills: ['painting', 'masonry'],
      bio: 'Interior/exterior painting, wall texture, tiling and grout work.',
      rating: 4.4, ratingCount: 9, jobsCompleted: 11, jobsAssigned: 12, avgResponseMinutes: 35, responseSamples: 12,
      experienceYears: 6, hourlyRate: 1300, kycStatus: 'pending'
    }),
    u({
      name: 'Hamza Sheikh', email: 'tech5@demo.com', role: 'technician', phone: '0300-1234507', city: 'Karachi',
      headline: 'Plumber', skills: ['plumbing'], bio: 'Bathroom and kitchen plumbing.',
      rating: 3.9, ratingCount: 4, jobsCompleted: 5, jobsAssigned: 7, avgResponseMinutes: 90, responseSamples: 7,
      experienceYears: 3, hourlyRate: 900
    }),
    u({
      name: 'Ayesha Malik', email: 'tech6@demo.com', role: 'technician', phone: '0300-1234508', city: 'Lahore',
      headline: 'Deep cleaning & pest control', skills: ['cleaning', 'pest_control'],
      bio: 'Team of 4. Deep cleaning, sofa/carpet shampoo, termite and cockroach treatment.',
      rating: 4.7, ratingCount: 15, jobsCompleted: 18, jobsAssigned: 18, avgResponseMinutes: 25, responseSamples: 18,
      experienceYears: 4, hourlyRate: 1100, kycStatus: 'approved'
    }),
    u({
      name: 'Farhan Qureshi', email: 'tech7@demo.com', role: 'technician', phone: '0300-1234509', city: 'Lahore',
      headline: 'Electrician (new to SureFix)', skills: ['electrical'],
      bio: 'Wiring, DB boxes, UPS and solar inverter installation.',
      experienceYears: 2, hourlyRate: 1000
    }),
    u({
      name: 'Imran Javed', email: 'tech8@demo.com', role: 'technician', phone: '0300-1234510', city: 'Rawalpindi',
      headline: 'Locksmith & door repairs', skills: ['locksmith', 'carpentry'],
      bio: 'Lockouts, lock changes, smart locks and door alignment.',
      rating: 4.5, ratingCount: 8, jobsCompleted: 9, jobsAssigned: 10, avgResponseMinutes: 20, responseSamples: 10,
      experienceYears: 7, hourlyRate: 1400, kycStatus: 'approved', isAvailable: false
    }),
    u({ name: 'ToolCo Rentals', email: 'supplier@demo.com', role: 'supplier', phone: '042-1234567', city: 'Lahore', kycStatus: 'approved',
      bio: 'Professional-grade tools for rent since 2015.' }),
    u({ name: 'BuildPro Equipment', email: 'supplier2@demo.com', role: 'supplier', phone: '021-7654321', city: 'Karachi' }),
    u({ name: 'Admin', email: 'admin@demo.com', role: 'admin', city: 'Lahore' })
  ]);
  // Spread join dates so "Member since" and the admin sign-up chart look real.
  const joined = { [sara.id]: 120, [bilal.id]: 45, [ahmad.id]: 400, [noor.id]: 210, [usman.id]: 620, [zainab.id]: 90,
    [hamza.id]: 6, [ayesha.id]: 300, [farhan.id]: 2, [imran.id]: 250, [toolco.id]: 500, [buildpro.id]: 4, [admin.id]: 700 };
  await Promise.all(Object.entries(joined).map(([id, days]) => User.collection.updateOne({ _id: new mongoose.Types.ObjectId(id) }, { $set: { createdAt: ago(days * DAY) } })));
  console.log('Seeded 13 demo users (password: password123)');

  // ------------------------------------------------------------------ jobs
  const job = (o) => new Job(o);
  const jobs = [];

  const sink = job({
    client: sara._id, title: 'Fix leaking kitchen sink', category: 'plumbing', urgency: 'high',
    description: 'Water is dripping from the pipe under the kitchen sink and the cabinet floor is getting wet. Need it fixed today if possible.',
    budget: 3000, location: 'House 12, Block C, Model Town', city: 'Lahore', createdAt: ago(5 * HOUR),
    bids: [
      { technician: ahmad._id, amount: 2800, etaDays: 0, message: 'I can come this afternoon with spare fittings.', createdAt: ago(4.5 * HOUR) },
      { technician: hamza._id, amount: 3500, etaDays: 2, message: 'Available day after tomorrow.', createdAt: ago(3 * HOUR) },
      { technician: noor._id, amount: 3200, etaDays: 1, message: 'Can also fix the cabinet base if it is damaged.', createdAt: ago(2 * HOUR) }
    ]
  });
  sink.history = [
    { status: 'pending', note: 'Job posted', by: sara._id, at: ago(5 * HOUR) },
    { status: 'bid', note: 'Ahmad Raza quoted 2800', by: ahmad._id, at: ago(4.5 * HOUR) },
    { status: 'bid', note: 'Hamza Sheikh quoted 3500', by: hamza._id, at: ago(3 * HOUR) },
    { status: 'bid', note: 'Noor Fatima quoted 3200', by: noor._id, at: ago(2 * HOUR) }
  ];
  jobs.push(sink);

  const fan = job({
    client: sara._id, title: 'Install ceiling fan in bedroom', category: 'electrical', urgency: 'normal',
    description: 'New ceiling fan needs to be installed. Hook and wiring are already in place.',
    budget: 2500, location: 'House 12, Block C, Model Town', city: 'Lahore', preferredDate: ahead(2 * DAY), createdAt: ago(40 * 60 * 1000),
    history: [{ status: 'pending', note: 'Job posted', by: sara._id, at: ago(40 * 60 * 1000) }]
  });
  jobs.push(fan);

  const ac = job({
    client: sara._id, title: 'AC not cooling — needs gas refill', category: 'hvac', urgency: 'high',
    description: 'The 1.5 ton split AC in the lounge runs but blows warm air. Probably needs a gas refill and service.',
    budget: 7000, location: 'House 12, Block C, Model Town', city: 'Lahore', createdAt: ago(2 * DAY),
    status: 'in_progress', assignedTechnician: usman._id, agreedPrice: 6000,
    bids: [
      { technician: usman._id, amount: 6000, etaDays: 0, message: 'Gas refill + full service, 3 month warranty.', status: 'accepted', createdAt: ago(2 * DAY - HOUR) },
      { technician: ahmad._id, amount: 6500, etaDays: 1, message: 'Can do tomorrow.', status: 'rejected', createdAt: ago(2 * DAY - 3 * HOUR) }
    ]
  });
  ac.acceptedBid = ac.bids[0]._id;
  ac.history = [
    { status: 'pending', note: 'Job posted', by: sara._id, at: ago(2 * DAY) },
    { status: 'bid', note: 'Usman Ali quoted 6000', by: usman._id, at: ago(2 * DAY - HOUR) },
    { status: 'in_progress', note: 'Hired Usman Ali for 6000', by: sara._id, at: ago(DAY + 20 * HOUR) }
  ];
  jobs.push(ac);

  const tap = job({
    client: sara._id, title: 'Replace bathroom tap', category: 'plumbing', urgency: 'normal',
    description: 'Old mixer tap in the main bathroom is loose and leaking from the base. New tap is already purchased.',
    budget: 2000, location: 'Model Town', city: 'Lahore', createdAt: ago(12 * DAY),
    status: 'completed', assignedTechnician: ahmad._id, agreedPrice: 1800, completedAt: ago(10 * DAY),
    rating: 5, review: 'Quick, tidy and explained everything. Highly recommended!',
    bids: [{ technician: ahmad._id, amount: 1800, etaDays: 1, status: 'accepted', createdAt: ago(12 * DAY - HOUR) }]
  });
  tap.acceptedBid = tap.bids[0]._id;
  tap.history = [
    { status: 'pending', note: 'Job posted', by: sara._id, at: ago(12 * DAY) },
    { status: 'in_progress', note: 'Hired Ahmad Raza for 1800', by: sara._id, at: ago(11 * DAY) },
    { status: 'completed', note: '', by: ahmad._id, at: ago(10 * DAY) },
    { status: 'rated', note: '5★', by: sara._id, at: ago(10 * DAY) }
  ];
  jobs.push(tap);

  const hinge = job({
    client: sara._id, title: 'Kitchen cabinet hinge repair', category: 'carpentry', urgency: 'low',
    description: 'Two cabinet doors are hanging loose. Hinges need replacing and doors realigned.',
    budget: 1500, location: 'Model Town', city: 'Lahore', createdAt: ago(20 * DAY),
    status: 'completed', assignedTechnician: noor._id, agreedPrice: 1400, completedAt: ago(18 * DAY),
    rating: 4, review: 'Good job, arrived a little late but the doors close perfectly now.',
    bids: [{ technician: noor._id, amount: 1400, etaDays: 2, status: 'accepted', createdAt: ago(20 * DAY - HOUR) }]
  });
  hinge.acceptedBid = hinge.bids[0]._id;
  hinge.history = [
    { status: 'pending', note: 'Job posted', by: sara._id, at: ago(20 * DAY) },
    { status: 'in_progress', note: 'Hired Noor Fatima for 1400', by: sara._id, at: ago(19 * DAY) },
    { status: 'completed', note: '', by: sara._id, at: ago(18 * DAY) }
  ];
  jobs.push(hinge);

  const clean = job({
    client: bilal._id, title: 'Deep cleaning before Eid', category: 'cleaning', urgency: 'normal',
    description: 'Full deep clean of a 3 bedroom apartment including kitchen grease and sofa shampoo.',
    budget: 8000, location: 'Flat 4B, Clifton Block 5', city: 'Karachi', preferredDate: ahead(4 * DAY), createdAt: ago(DAY),
    bids: [{ technician: ayesha._id, amount: 7500, etaDays: 3, message: 'Team of 3, all supplies included.', createdAt: ago(20 * HOUR) }],
    history: [{ status: 'pending', note: 'Job posted', by: bilal._id, at: ago(DAY) }]
  });
  jobs.push(clean);

  const dbBox = job({
    client: bilal._id, title: 'Install new distribution (DB) box', category: 'electrical', urgency: 'normal',
    description: 'Old fuse box keeps tripping. Want a new DB box with breakers for each room.',
    budget: 12000, location: 'Clifton Block 5', city: 'Karachi', createdAt: ago(3 * HOUR),
    requestedTechnician: ahmad._id,
    history: [{ status: 'pending', note: 'Service requested from Ahmad Raza', by: bilal._id, at: ago(3 * HOUR) }]
  });
  jobs.push(dbBox);

  const termite = job({
    client: bilal._id, title: 'Termite treatment for wooden doors', category: 'pest_control', urgency: 'normal',
    description: 'Termites in two wooden door frames.', budget: 5000, city: 'Karachi', createdAt: ago(9 * DAY),
    status: 'cancelled', cancelledAt: ago(8 * DAY), cancelReason: 'Landlord arranged the treatment',
    history: [
      { status: 'pending', note: 'Job posted', by: bilal._id, at: ago(9 * DAY) },
      { status: 'cancelled', note: 'Landlord arranged the treatment', by: bilal._id, at: ago(8 * DAY) }
    ]
  });
  jobs.push(termite);

  for (const j of jobs) await j.save();

  // Past, reviewed jobs so each technician's rating/review count is backed
  // by real reviews (the profile's star breakdown reads them).
  const reviewers = await User.create(
    ['Ali Hassan', 'Hina Javed', 'Omar Farooq', 'Mariam Shah', 'Kamran Butt'].map((name, i) =>
      u({ name, email: `reviewer${i + 1}@demo.com`, role: 'client', city: ['Lahore', 'Karachi', 'Islamabad', 'Lahore', 'Rawalpindi'][i] })
    )
  );
  await Promise.all(reviewers.map((r, i) => User.collection.updateOne({ _id: r._id }, { $set: { createdAt: ago((i + 1) * DAY) } })));
  const PRAISE = {
    5: ['Excellent work, very professional.', 'On time and left everything spotless.', 'Fixed it in no time. Highly recommended!', 'Fair price and great quality.', ''],
    4: ['Good job overall, arrived a little late.', 'Solid work, would hire again.', 'Did the job well, slightly over the quote.', ''],
    3: ['Got it done but communication could be better.', 'Okay work, took longer than expected.']
  };
  const TITLES = {
    plumbing: ['Replace kitchen mixer tap', 'Unblock bathroom drain', 'Fix running toilet', 'Install water filter'],
    electrical: ['Install ceiling fan', 'Replace burnt switchboard', 'Fix tripping breaker', 'Wire new sockets'],
    carpentry: ['Repair wardrobe door', 'Fix squeaky bed frame', 'Install floating shelves'],
    hvac: ['AC gas refill and service', 'Install split AC', 'Fix AC water leakage'],
    appliance: ['Fix washing machine spin', 'Fridge not cooling'],
    painting: ['Repaint bedroom walls', 'Paint main gate'],
    masonry: ['Retile bathroom floor', 'Fix cracked plaster'],
    cleaning: ['Deep clean 3-bed house', 'Sofa and carpet shampoo'],
    pest_control: ['Cockroach treatment', 'Termite treatment'],
    locksmith: ['Change front door lock', 'Install smart lock'],
    general: ['Mount TV and shelves', 'Assemble furniture']
  };
  let historyCount = 0;
  for (const tech of [ahmad, noor, usman, zainab, hamza, ayesha, imran]) {
    const target = tech.rating;
    const existing = await Job.countDocuments({ assignedTechnician: tech._id, rating: { $ne: null } });
    const n = tech.ratingCount - existing;
    const fives = Math.max(0, Math.min(n, Math.round(n * (target - 4))));
    for (let i = 0; i < n; i++) {
      const rating = target >= 4 ? (i < fives ? 5 : 4) : (i < Math.round(n * (target - 3)) ? 4 : 3);
      const cat = tech.skills[i % tech.skills.length];
      const titles = TITLES[cat] || TITLES.general;
      const client = reviewers[i % reviewers.length];
      const daysAgo = 20 + i * 9;
      const price = 1500 + ((i * 937) % 6000);
      const bid = { technician: tech._id, amount: price, etaDays: 1, status: 'accepted', createdAt: ago(daysAgo * DAY + HOUR) };
      const job = new Job({
        client: client._id, title: titles[i % titles.length], description: 'Completed through SureFix.', category: cat,
        budget: price, city: client.city, status: 'completed', assignedTechnician: tech._id, agreedPrice: price,
        completedAt: ago((daysAgo - 1) * DAY), createdAt: ago(daysAgo * DAY), bids: [bid],
        rating, review: PRAISE[rating][i % PRAISE[rating].length]
      });
      job.acceptedBid = job.bids[0]._id;
      job.history = [
        { status: 'pending', note: 'Job posted', by: client._id, at: ago(daysAgo * DAY) },
        { status: 'in_progress', note: `Hired ${tech.name} for ${price}`, by: client._id, at: ago(daysAgo * DAY - 2 * HOUR) },
        { status: 'completed', note: '', by: tech._id, at: ago((daysAgo - 1) * DAY) },
        { status: 'rated', note: `${rating}★`, by: client._id, at: ago((daysAgo - 1) * DAY) }
      ];
      await job.save();
      historyCount += 1;
    }
    // Make the profile average exactly match the stored reviews.
    const agg = await Job.aggregate([
      { $match: { assignedTechnician: tech._id, rating: { $ne: null } } },
      { $group: { _id: null, avg: { $avg: '$rating' }, n: { $sum: 1 } } }
    ]);
    if (agg[0]) {
      await User.updateOne({ _id: tech._id }, { $set: { rating: Math.round(agg[0].avg * 100) / 100, ratingCount: agg[0].n } });
    }
  }
  console.log(`Seeded ${jobs.length} jobs + ${historyCount} past reviewed jobs`);

  // ----------------------------------------------------------------- tools
  const t = (o) => ({ supplier: toolco._id, city: 'Lahore', condition: 'good', stock: 2, ...o });
  const tools = await Tool.create([
    t({ name: 'Bosch Cordless Drill 18V', category: 'power', condition: 'like_new', description: '18V cordless drill/driver with 2 batteries, charger and a 30-piece bit set.',
      rentPricePerDay: 800, deposit: 5000, purchasePrice: 32000, installmentMonths: 6, installmentMonthly: 5500, stock: 4, rating: 4.8, ratingCount: 5, rentalsCount: 12 }),
    t({ name: 'Pipe Wrench Set (3 pcs)', category: 'plumbing', description: '10", 14" and 18" heavy-duty adjustable pipe wrenches.',
      rentPricePerDay: 300, deposit: 1500, purchasePrice: 6500, stock: 6, rentalsCount: 4 }),
    t({ name: 'Manual Tile Cutter 24"', category: 'hand', description: 'Cuts ceramic and porcelain tiles up to 24 inches. Includes spare wheel.',
      rentPricePerDay: 600, deposit: 3000, purchasePrice: 14000, installmentMonths: 3, installmentMonthly: 4800, stock: 2, rating: 4.5, ratingCount: 2, rentalsCount: 3 }),
    t({ name: 'Aluminium Extension Ladder 12 ft', category: 'ladders', description: 'Lightweight two-section ladder, 150 kg load rating.',
      rentPricePerDay: 500, deposit: 2500, purchasePrice: 18000, stock: 3, rating: 5, ratingCount: 1, rentalsCount: 6 }),
    t({ name: 'Karcher Pressure Washer', category: 'cleaning', condition: 'like_new', description: '130 bar pressure washer for driveways, cars and terraces.',
      rentPricePerDay: 1500, deposit: 8000, purchasePrice: 45000, installmentMonths: 6, installmentMonthly: 7800, stock: 2, rating: 4.6, ratingCount: 3, rentalsCount: 7 }),
    t({ name: 'Digital Multimeter', category: 'measurement', description: 'Auto-ranging multimeter with continuity buzzer and probes.',
      rentPricePerDay: 250, deposit: 1000, purchasePrice: 4500, stock: 5, rentalsCount: 2 }),
    t({ name: 'Wet & Dry Vacuum 30L', category: 'cleaning', description: 'Industrial wet/dry vacuum with blower function.',
      rentPricePerDay: 900, deposit: 4000, purchasePrice: 26000, stock: 1, rentalsCount: 1 }),
    t({ name: 'Angle Grinder 4.5"', category: 'power', description: '850W angle grinder with cutting and grinding discs. Safety glasses included.',
      rentPricePerDay: 700, deposit: 3000, purchasePrice: 12000, installmentMonths: 3, installmentMonthly: 4200, stock: 3 }),
    t({ supplier: buildpro._id, city: 'Karachi', name: 'Concrete Mixer (half bag)', category: 'power', condition: 'fair', description: 'Electric drum mixer for small construction jobs. Delivery available.',
      rentPricePerDay: 3500, deposit: 15000, purchasePrice: 120000, stock: 1, rentalsCount: 2 }),
    t({ supplier: buildpro._id, city: 'Karachi', name: 'Petrol Lawn Mower', category: 'gardening', description: 'Self-propelled 21" petrol mower with grass bag.',
      rentPricePerDay: 1200, deposit: 6000, purchasePrice: 55000, installmentMonths: 6, installmentMonthly: 9500, stock: 2 }),
    t({ supplier: buildpro._id, city: 'Karachi', name: 'Self-levelling Laser Level', category: 'measurement', condition: 'new', description: 'Cross-line laser with tripod, ideal for tiling and shelving.',
      rentPricePerDay: 1000, deposit: 5000, purchasePrice: 28000, stock: 2 })
  ]);
  console.log(`Seeded ${tools.length} tools`);
  const [drill, , , ladder, washer, multimeter] = tools;

  await Rental.create([
    { tool: drill._id, renter: sara._id, supplier: toolco._id, type: 'rent', days: 5, startDate: ago(2 * DAY), endDate: ahead(3 * DAY),
      totalCost: 4000, deposit: 5000, status: 'active', approvedAt: ago(2 * DAY), fulfillment: 'pickup', createdAt: ago(2 * DAY + HOUR) },
    { tool: washer._id, renter: bilal._id, supplier: toolco._id, type: 'rent', days: 2, startDate: ahead(DAY), endDate: ahead(3 * DAY),
      totalCost: 3000, deposit: 8000, status: 'requested', fulfillment: 'delivery', note: 'Please deliver before 10am.', createdAt: ago(2 * HOUR) },
    { tool: ladder._id, renter: sara._id, supplier: toolco._id, type: 'rent', days: 1, startDate: ago(15 * DAY), endDate: ago(14 * DAY),
      totalCost: 500, deposit: 2500, status: 'returned', approvedAt: ago(15 * DAY), returnedAt: ago(14 * DAY), rating: 5,
      review: 'Sturdy and clean. Easy pickup.', createdAt: ago(15 * DAY) },
    { tool: multimeter._id, renter: ahmad._id, supplier: toolco._id, type: 'rent', days: 3, startDate: ago(4 * DAY), endDate: ago(DAY),
      totalCost: 750, deposit: 1000, status: 'active', approvedAt: ago(4 * DAY), createdAt: ago(4 * DAY + HOUR) },
    { tool: drill._id, renter: bilal._id, supplier: toolco._id, type: 'installment', totalCost: 32000, monthsRemaining: 6,
      status: 'requested', startDate: new Date(), createdAt: ago(HOUR) }
  ]);
  // Stock reflects the two active rentals.
  await Tool.updateOne({ _id: drill._id }, { $inc: { stock: -1 } });
  await Tool.updateOne({ _id: multimeter._id }, { $inc: { stock: -1 } });
  console.log('Seeded 5 rentals');

  // -------------------------------------------------------------- messages
  const m = (job, from, to, text, at, read = true) => ({ job: job._id, sender: from._id, recipient: to._id, text, createdAt: at, readAt: read ? at : null });
  await Message.create([
    m(ac, sara, usman, 'Hi Usman, is the gas refill included in the 6000?', ago(DAY + 19 * HOUR)),
    m(ac, usman, sara, 'Yes, refill plus a full indoor and outdoor unit service.', ago(DAY + 18.5 * HOUR)),
    m(ac, sara, usman, 'Great. Can you come tomorrow at 11?', ago(DAY + 18 * HOUR)),
    m(ac, usman, sara, 'Confirmed for 11am. I will bring the gas cylinder.', ago(DAY + 17 * HOUR)),
    m(ac, usman, sara, 'On my way, 15 minutes out.', ago(30 * 60 * 1000), false),
    m(sink, sara, ahmad, 'Do you have the fittings for a 1/2" pipe?', ago(4 * HOUR)),
    m(sink, ahmad, sara, 'Yes, I carry standard 1/2" and 3/4" fittings in the van.', ago(3.8 * HOUR), false)
  ]);
  console.log('Seeded 7 chat messages');

  await Notification.create([
    { user: sara._id, type: 'bid', title: 'New quote on your job', body: 'Noor Fatima quoted 3200 for "Fix leaking kitchen sink"', data: { jobId: sink._id }, createdAt: ago(2 * HOUR) },
    { user: sara._id, type: 'bid', title: 'New quote on your job', body: 'Hamza Sheikh quoted 3500 for "Fix leaking kitchen sink"', data: { jobId: sink._id }, createdAt: ago(3 * HOUR) },
    { user: sara._id, type: 'rental', title: 'Your rental was approved', body: '"Bosch Cordless Drill 18V" is ready for pickup', data: { rentalId: null }, readAt: ago(DAY), createdAt: ago(2 * DAY) },
    { user: ahmad._id, type: 'request', title: 'New service request', body: 'Bilal Ahmed requested you for "Install new distribution (DB) box"', data: { jobId: dbBox._id }, createdAt: ago(3 * HOUR) },
    { user: ahmad._id, type: 'review', title: 'New 5★ review', body: 'Quick, tidy and explained everything. Highly recommended!', data: { jobId: tap._id }, readAt: ago(9 * DAY), createdAt: ago(10 * DAY) },
    { user: usman._id, type: 'job_status', title: 'You got the job!', body: 'You were hired for "AC not cooling — needs gas refill"', data: { jobId: ac._id }, createdAt: ago(DAY + 20 * HOUR) },
    { user: toolco._id, type: 'rental', title: 'New rental request', body: 'Bilal Ahmed wants "Karcher Pressure Washer" for 2 days', data: { toolId: washer._id }, createdAt: ago(2 * HOUR) }
  ]);

  await Kyc.create({ user: zainab._id, fullName: 'Zainab Hussain', idType: 'cnic', idNumber: '35202-1234567-8', status: 'pending' });
  await Report.create({
    reporter: bilal._id, targetType: 'user', targetId: hamza._id, targetLabel: 'Hamza Sheikh (technician)',
    reason: 'no_show', details: 'Agreed on a visit time and never showed up or answered calls.'
  });
  console.log('Seeded notifications, 1 KYC submission, 1 report');

  console.log('\nDemo accounts (password: password123):');
  [sara, bilal, ahmad, usman, toolco, admin].forEach((x) => console.log(`  ${x.role.padEnd(10)} ${x.email}`));
  await mongoose.disconnect();
  console.log('Done.');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
