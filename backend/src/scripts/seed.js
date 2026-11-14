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
const Transaction = require('../models/Transaction');
const PaymentAccount = require('../models/PaymentAccount');
const WalletRequest = require('../models/WalletRequest');

const DAY = 24 * 3600 * 1000;
const HOUR = 3600 * 1000;
const MIN = 60 * 1000;
const ago = (ms) => new Date(Date.now() - ms);
const ahead = (ms) => new Date(Date.now() + ms);
const PASSWORD = 'password123';
const fee = (amount) => Math.round((amount * config.platformFeePercent) / 100);

// Wallet ledger rows, collected while seeding and written at the end so each
// demo wallet's balance is exactly the sum of its history.
const ledger = [];
const move = (user, type, amount, at, ref = {}) => ledger.push({ user: user ? user._id : null, type, amount, createdAt: at, ...ref });

// Payment state for a finished or running job / rental.
const walletPay = (amount, status, extra = {}) => ({ method: 'wallet', status, amount, fee: fee(amount), net: amount - fee(amount), ...extra });
const cashPay = (amount, status, extra = {}) => ({ method: 'cash', status, amount, fee: 0, net: amount, ...extra });

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
  await Promise.all([User, Job, Tool, Rental, Message, Notification, Kyc, Report, Transaction, PaymentAccount, WalletRequest].map((M) => M.deleteMany({})));

  // ----------------------------------------------------------------- users
  const u = (o) => ({ password: PASSWORD, ...o });
  const tech = (o) => u({ role: 'technician', ...o });
  const [sara, bilal, ahmad, noor, usman, zainab, hamza, ayesha, farhan, imran, toolco, buildpro, admin] = await User.create([
    u({ name: 'Sara Khan', email: 'client@demo.com', role: 'client', phone: '0300-1234501', city: 'Lahore', address: 'House 14, Street 7, DHA Phase 4, Lahore' }),
    u({ name: 'Bilal Ahmed', email: 'client2@demo.com', role: 'client', phone: '0300-1234502', city: 'Karachi', address: 'Flat 302, Block B, Gulshan-e-Iqbal, Karachi' }),
    tech({
      name: 'Ahmad Raza', email: 'tech@demo.com', phone: '0300-1234503', city: 'Lahore',
      headline: 'Licensed electrician & plumber', skills: ['plumbing', 'electrical'],
      bio: 'Licensed electrician with 8 years of residential experience. Neat work, fair quotes, and I clean up after myself.',
      rating: 4.6, ratingCount: 12, avgResponseMinutes: 22, responseSamples: 15, experienceYears: 8, hourlyRate: 1500, kycStatus: 'approved'
    }),
    tech({
      name: 'Noor Fatima', email: 'tech2@demo.com', phone: '0300-1234504', city: 'Lahore',
      headline: 'Carpenter & handywoman', skills: ['carpentry', 'general'],
      bio: 'Custom furniture repairs, cabinet fitting and all the small jobs around the house.',
      rating: 4.1, ratingCount: 6, avgResponseMinutes: 45, responseSamples: 9, experienceYears: 5, hourlyRate: 1200, kycStatus: 'approved'
    }),
    tech({
      name: 'Usman Ali', email: 'tech3@demo.com', phone: '0300-1234505', city: 'Lahore',
      headline: 'AC & appliance specialist', skills: ['hvac', 'appliance'],
      bio: 'Split AC installation, gas refills, inverter AC and fridge repairs. Certified by two major brands.',
      rating: 4.8, ratingCount: 21, avgResponseMinutes: 15, responseSamples: 26, experienceYears: 10, hourlyRate: 2000, kycStatus: 'approved'
    }),
    tech({
      name: 'Zainab Hussain', email: 'tech4@demo.com', phone: '0300-1234506', city: 'Islamabad',
      headline: 'Painter & tiling expert', skills: ['painting', 'masonry'],
      bio: 'Interior/exterior painting, wall texture, tiling and grout work.',
      rating: 4.4, ratingCount: 9, avgResponseMinutes: 35, responseSamples: 12, experienceYears: 6, hourlyRate: 1300, kycStatus: 'pending'
    }),
    tech({
      name: 'Hamza Sheikh', email: 'tech5@demo.com', phone: '0300-1234507', city: 'Karachi',
      headline: 'Plumber', skills: ['plumbing'], bio: 'Bathroom and kitchen plumbing.',
      rating: 3.9, ratingCount: 4, avgResponseMinutes: 90, responseSamples: 7, experienceYears: 3, hourlyRate: 900
    }),
    tech({
      name: 'Ayesha Malik', email: 'tech6@demo.com', phone: '0300-1234508', city: 'Lahore',
      headline: 'Deep cleaning & pest control', skills: ['cleaning', 'pest_control'],
      bio: 'Team of 4. Deep cleaning, sofa/carpet shampoo, termite and cockroach treatment.',
      rating: 4.7, ratingCount: 15, avgResponseMinutes: 25, responseSamples: 18, experienceYears: 4, hourlyRate: 1100, kycStatus: 'approved'
    }),
    tech({
      name: 'Farhan Qureshi', email: 'tech7@demo.com', phone: '0300-1234509', city: 'Lahore',
      headline: 'Electrician (new to SureFix)', skills: ['electrical'],
      bio: 'Wiring, DB boxes, UPS and solar inverter installation.', experienceYears: 2, hourlyRate: 1000
    }),
    tech({
      name: 'Imran Javed', email: 'tech8@demo.com', phone: '0300-1234510', city: 'Rawalpindi',
      headline: 'Locksmith & door repairs', skills: ['locksmith', 'carpentry'],
      bio: 'Lockouts, lock changes, smart locks and door alignment.',
      rating: 4.5, ratingCount: 8, avgResponseMinutes: 20, responseSamples: 10, experienceYears: 7, hourlyRate: 1400, kycStatus: 'approved', isAvailable: false
    }),
    u({
      name: 'ToolCo Rentals', email: 'supplier@demo.com', role: 'supplier', phone: '042-1234567', city: 'Lahore', kycStatus: 'approved',
      headline: 'Pro tools for every job', address: 'Shop 12, Hall Road Tool Market, Lahore (open 10am–8pm, closed Sunday)',
      bio: 'Professional-grade tools for rent since 2015.'
    }),
    u({
      name: 'BuildPro Equipment', email: 'supplier2@demo.com', role: 'supplier', phone: '021-7654321', city: 'Karachi',
      address: 'Plot 45, Sector 7-A, Korangi Industrial Area, Karachi'
    }),
    u({ name: 'Admin', email: 'admin@demo.com', role: 'admin', city: 'Lahore' })
  ]);
  // Spread join dates so "Member since" and the admin sign-up chart look real.
  const joined = [[sara, 120], [bilal, 45], [ahmad, 400], [noor, 210], [usman, 620], [zainab, 90], [hamza, 6], [ayesha, 300], [farhan, 2], [imran, 250], [toolco, 500], [buildpro, 4], [admin, 700]];
  await Promise.all(joined.map(([user, days]) => User.collection.updateOne({ _id: user._id }, { $set: { createdAt: ago(days * DAY) } })));
  console.log('Seeded 13 demo users (password: password123)');

  // ------------------------------------------------------------------ jobs
  const ev = (event, by, at, note = '') => ({ event, by: by._id, at, note });
  const jobs = [];
  const add = (o) => {
    const job = new Job(o);
    const accepted = job.bids.find((b) => b.status === 'accepted');
    if (accepted) job.acceptedBid = accepted._id;
    jobs.push(job);
    return job;
  };
  const home = 'House 14, Street 7, DHA Phase 4';

  const sink = add({
    client: sara._id, title: 'Fix leaking kitchen sink', category: 'plumbing', urgency: 'high',
    description: 'Water is dripping from the pipe under the kitchen sink and the cabinet floor is getting wet. Need it fixed today if possible.',
    budget: 3000, location: home, city: 'Lahore', createdAt: ago(5 * HOUR),
    bids: [
      { technician: ahmad._id, amount: 2800, etaDays: 0, message: 'I can come this afternoon with spare fittings.', createdAt: ago(4.5 * HOUR) },
      { technician: hamza._id, amount: 3500, etaDays: 2, message: 'Available day after tomorrow.', createdAt: ago(3 * HOUR) },
      { technician: noor._id, amount: 3200, etaDays: 1, message: 'Can also fix the cabinet base if it is damaged.', createdAt: ago(2 * HOUR) }
    ],
    history: [
      ev('posted', sara, ago(5 * HOUR), 'Job posted'),
      ev('bid', ahmad, ago(4.5 * HOUR), 'Ahmad Raza quoted 2800'),
      ev('bid', hamza, ago(3 * HOUR), 'Hamza Sheikh quoted 3500'),
      ev('bid', noor, ago(2 * HOUR), 'Noor Fatima quoted 3200')
    ]
  });

  add({
    client: sara._id, title: 'Install ceiling fan in bedroom', category: 'electrical', urgency: 'normal',
    description: 'New ceiling fan needs to be installed. Hook and wiring are already in place.',
    budget: 2500, location: home, city: 'Lahore', preferredDate: ahead(2 * DAY), createdAt: ago(40 * MIN),
    history: [ev('posted', sara, ago(40 * MIN), 'Job posted')]
  });

  // Hired, paid into escrow, technician is working right now.
  const ac = add({
    client: sara._id, title: 'AC not cooling — needs gas refill', category: 'hvac', urgency: 'high',
    description: 'The 1.5 ton split AC in the lounge runs but blows warm air. Probably needs a gas refill and service.',
    budget: 7000, location: home, city: 'Lahore', createdAt: ago(2 * DAY),
    status: 'in_progress', stage: 'working', assignedTechnician: usman._id, agreedPrice: 6000, hiredAt: ago(DAY + 20 * HOUR),
    payment: walletPay(6000, 'held', { heldAt: ago(DAY + 20 * HOUR) }),
    bids: [
      { technician: usman._id, amount: 6000, etaDays: 0, message: 'Gas refill + full service, 3 month warranty.', status: 'accepted', createdAt: ago(2 * DAY - HOUR) },
      { technician: ahmad._id, amount: 6500, etaDays: 1, message: 'Can do tomorrow.', status: 'rejected', createdAt: ago(2 * DAY - 3 * HOUR) }
    ],
    history: [
      ev('posted', sara, ago(2 * DAY), 'Job posted'),
      ev('bid', usman, ago(2 * DAY - HOUR), 'Usman Ali quoted 6000'),
      ev('hired', sara, ago(DAY + 20 * HOUR), 'Hired Usman Ali for 6000 (paid into escrow)'),
      ev('on_the_way', usman, ago(50 * MIN)),
      ev('working', usman, ago(20 * MIN))
    ]
  });

  // Work finished, waiting for the client to confirm (cash job).
  const socket = add({
    client: sara._id, title: 'Sparking wall socket in lounge', category: 'electrical', urgency: 'emergency',
    description: 'The socket behind the TV sparks when anything is plugged in and smells of burning. Switched off at the breaker for now.',
    budget: 2000, location: home, city: 'Lahore', createdAt: ago(DAY + 2 * HOUR),
    status: 'in_progress', stage: 'done', assignedTechnician: ahmad._id, agreedPrice: 1800, hiredAt: ago(DAY),
    doneAt: ago(3 * HOUR), completionNote: 'Replaced the burnt socket and the damaged wire behind it. Tested with a load — all safe now.',
    payment: cashPay(1800, 'cash_due'),
    bids: [{ technician: ahmad._id, amount: 1800, etaDays: 0, message: 'I am nearby and can come within the hour.', status: 'accepted', createdAt: ago(DAY + HOUR) }],
    history: [
      ev('posted', sara, ago(DAY + 2 * HOUR), 'Job posted'),
      ev('bid', ahmad, ago(DAY + HOUR), 'Ahmad Raza quoted 1800'),
      ev('hired', sara, ago(DAY), 'Hired Ahmad Raza for 1800 (cash on completion)'),
      ev('on_the_way', ahmad, ago(5 * HOUR)),
      ev('working', ahmad, ago(4.5 * HOUR)),
      ev('done', ahmad, ago(3 * HOUR), 'Replaced the burnt socket and the damaged wire behind it.')
    ]
  });

  const tap = add({
    client: sara._id, title: 'Replace bathroom tap', category: 'plumbing', urgency: 'normal',
    description: 'Old mixer tap in the main bathroom is loose and leaking from the base. New tap is already purchased.',
    budget: 2000, location: home, city: 'Lahore', createdAt: ago(12 * DAY),
    status: 'completed', stage: 'done', assignedTechnician: ahmad._id, agreedPrice: 1800, hiredAt: ago(11 * DAY),
    doneAt: ago(10 * DAY), completedAt: ago(10 * DAY), payment: walletPay(1800, 'released', { heldAt: ago(11 * DAY), settledAt: ago(10 * DAY) }),
    rating: 5, review: 'Quick, tidy and explained everything. Highly recommended!',
    bids: [{ technician: ahmad._id, amount: 1800, etaDays: 1, status: 'accepted', createdAt: ago(12 * DAY - HOUR) }],
    history: [
      ev('posted', sara, ago(12 * DAY), 'Job posted'),
      ev('hired', sara, ago(11 * DAY), 'Hired Ahmad Raza for 1800 (paid into escrow)'),
      ev('done', ahmad, ago(10 * DAY + HOUR)),
      ev('completed', sara, ago(10 * DAY)),
      ev('rated', sara, ago(10 * DAY), '5★')
    ]
  });

  add({
    client: sara._id, title: 'Kitchen cabinet hinge repair', category: 'carpentry', urgency: 'low',
    description: 'Two cabinet doors are hanging loose. Hinges need replacing and doors realigned.',
    budget: 1500, location: home, city: 'Lahore', createdAt: ago(20 * DAY),
    status: 'completed', stage: 'done', assignedTechnician: noor._id, agreedPrice: 1400, hiredAt: ago(19 * DAY),
    doneAt: ago(18 * DAY), completedAt: ago(18 * DAY), payment: cashPay(1400, 'cash_paid', { settledAt: ago(18 * DAY) }),
    rating: 4, review: 'Good job, arrived a little late but the doors close perfectly now.',
    bids: [{ technician: noor._id, amount: 1400, etaDays: 2, status: 'accepted', createdAt: ago(20 * DAY - HOUR) }],
    history: [
      ev('posted', sara, ago(20 * DAY), 'Job posted'),
      ev('hired', sara, ago(19 * DAY), 'Hired Noor Fatima for 1400 (cash on completion)'),
      ev('completed', sara, ago(18 * DAY)),
      ev('rated', sara, ago(18 * DAY), '4★')
    ]
  });

  add({
    client: bilal._id, title: 'Deep cleaning before Eid', category: 'cleaning', urgency: 'normal',
    description: 'Full deep clean of a 3 bedroom apartment including kitchen grease and sofa shampoo.',
    budget: 8000, location: 'Flat 302, Block B, Gulshan-e-Iqbal', city: 'Karachi', preferredDate: ahead(4 * DAY), createdAt: ago(DAY),
    bids: [{ technician: ayesha._id, amount: 7500, etaDays: 3, message: 'Team of 3, all supplies included.', createdAt: ago(20 * HOUR) }],
    history: [ev('posted', bilal, ago(DAY), 'Job posted'), ev('bid', ayesha, ago(20 * HOUR), 'Ayesha Malik quoted 7500')]
  });

  const dbBox = add({
    client: bilal._id, title: 'Install new distribution (DB) box', category: 'electrical', urgency: 'normal',
    description: 'Old fuse box keeps tripping. Want a new DB box with breakers for each room.',
    budget: 12000, location: 'Flat 302, Block B, Gulshan-e-Iqbal', city: 'Karachi', createdAt: ago(3 * HOUR),
    requestedTechnician: ahmad._id,
    history: [ev('posted', bilal, ago(3 * HOUR), 'Service requested from Ahmad Raza')]
  });

  add({
    client: bilal._id, title: 'Termite treatment for wooden doors', category: 'pest_control', urgency: 'normal',
    description: 'Termites in two wooden door frames.', budget: 5000, city: 'Karachi', createdAt: ago(9 * DAY),
    status: 'cancelled', cancelledAt: ago(8 * DAY), cancelReason: 'Landlord arranged the treatment',
    history: [ev('posted', bilal, ago(9 * DAY), 'Job posted'), ev('cancelled', bilal, ago(8 * DAY), 'Landlord arranged the treatment')]
  });

  // Sara's wallet history for the jobs above (her rentals are added below).
  move(sara, 'deposit', 20000, ago(30 * DAY), { note: 'Meezan Bank · TX MZ88120345' });
  move(sara, 'job_hold', -1800, ago(11 * DAY), { job: tap._id, note: tap.title });
  move(ahmad, 'job_earning', 1800 - fee(1800), ago(10 * DAY), { job: tap._id, note: tap.title });
  move(null, 'platform_fee', fee(1800), ago(10 * DAY), { job: tap._id, note: tap.title });
  move(sara, 'deposit', 10000, ago(3 * DAY), { note: 'JazzCash · TX JC51200987' });
  move(sara, 'job_hold', -6000, ago(DAY + 20 * HOUR), { job: ac._id, note: ac.title });

  // Past, reviewed jobs so each technician's rating, review count, earnings
  // and price history are backed by real records.
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
  const WORK = {
    plumbing: { titles: ['Replace kitchen mixer tap', 'Unblock bathroom drain', 'Fix running toilet', 'Install water filter'], price: [1500, 4200] },
    electrical: { titles: ['Install ceiling fan', 'Replace burnt switchboard', 'Fix tripping breaker', 'Wire new sockets'], price: [1200, 3800] },
    carpentry: { titles: ['Repair wardrobe door', 'Fix squeaky bed frame', 'Install floating shelves'], price: [1800, 6500] },
    hvac: { titles: ['AC gas refill and service', 'Install split AC', 'Fix AC water leakage'], price: [3000, 7500] },
    appliance: { titles: ['Fix washing machine spin', 'Fridge not cooling'], price: [2200, 5500] },
    painting: { titles: ['Repaint bedroom walls', 'Paint main gate'], price: [6000, 22000] },
    masonry: { titles: ['Retile bathroom floor', 'Fix cracked plaster'], price: [5000, 18000] },
    cleaning: { titles: ['Deep clean 3-bed house', 'Sofa and carpet shampoo'], price: [2500, 7500] },
    pest_control: { titles: ['Cockroach treatment', 'Termite treatment'], price: [3000, 7000] },
    locksmith: { titles: ['Change front door lock', 'Install smart lock'], price: [1200, 3500] },
    general: { titles: ['Mount TV and shelves', 'Assemble furniture'], price: [1200, 4500] }
  };
  let past = 0;
  for (const t of [ahmad, noor, usman, zainab, hamza, ayesha, imran]) {
    const n = t.ratingCount - jobs.filter((j) => String(j.assignedTechnician) === String(t._id) && j.rating).length;
    const fives = Math.max(0, Math.min(n, Math.round(n * (t.rating - 4))));
    for (let i = 0; i < n; i++) {
      const rating = t.rating >= 4 ? (i < fives ? 5 : 4) : i < Math.round(n * (t.rating - 3)) ? 4 : 3;
      const category = t.skills[i % t.skills.length];
      const work = WORK[category] || WORK.general;
      const client = reviewers[(i + t.name.length) % reviewers.length];
      const daysAgo = 3 + i * 8;
      const [low, high] = work.price;
      const price = Math.round((low + ((i * 937 + t.name.length * 211) % (high - low))) / 100) * 100;
      const byWallet = i % 3 !== 2;
      const completedAt = ago((daysAgo - 1) * DAY);
      const job = add({
        client: client._id, title: work.titles[i % work.titles.length], description: 'Completed through SureFix.', category,
        budget: price, city: client.city, status: 'completed', stage: 'done', assignedTechnician: t._id, agreedPrice: price,
        hiredAt: ago(daysAgo * DAY - 2 * HOUR), doneAt: completedAt, completedAt, createdAt: ago(daysAgo * DAY),
        payment: byWallet ? walletPay(price, 'released', { settledAt: completedAt }) : cashPay(price, 'cash_paid', { settledAt: completedAt }),
        bids: [{ technician: t._id, amount: price, etaDays: 1, status: 'accepted', createdAt: ago(daysAgo * DAY - HOUR) }],
        rating, review: PRAISE[rating][i % PRAISE[rating].length],
        history: [
          ev('posted', client, ago(daysAgo * DAY), 'Job posted'),
          ev('hired', client, ago(daysAgo * DAY - 2 * HOUR), `Hired ${t.name} for ${price}`),
          ev('completed', client, completedAt),
          ev('rated', client, completedAt, `${rating}★`)
        ]
      });
      if (byWallet) {
        move(t, 'job_earning', price - fee(price), completedAt, { job: job._id, note: job.title });
        move(null, 'platform_fee', fee(price), completedAt, { job: job._id, note: job.title });
      }
      past += 1;
    }
  }
  for (const j of jobs) await j.save();

  // Technician stats come from the jobs themselves, so they always agree.
  for (const t of [ahmad, noor, usman, zainab, hamza, ayesha, imran]) {
    const mine = jobs.filter((j) => String(j.assignedTechnician) === String(t._id));
    const rated = mine.filter((j) => j.rating);
    const completed = mine.filter((j) => j.status === 'completed').length;
    await User.updateOne(
      { _id: t._id },
      {
        $set: {
          jobsCompleted: completed,
          jobsAssigned: mine.length + (t.name === 'Hamza Sheikh' ? 2 : t.name === 'Noor Fatima' ? 1 : 0), // a couple of no-shows
          ratingCount: rated.length,
          rating: rated.length ? Math.round((rated.reduce((s, j) => s + j.rating, 0) / rated.length) * 100) / 100 : 0
        }
      }
    );
  }
  console.log(`Seeded ${jobs.length - past} current jobs + ${past} past reviewed jobs`);

  // ----------------------------------------------------------------- tools
  const tl = (o) => ({ supplier: toolco._id, city: 'Lahore', condition: 'good', stock: 2, ...o });
  const tools = await Tool.create([
    tl({ name: 'Bosch Cordless Drill 18V', category: 'power', condition: 'like_new', description: '18V cordless drill/driver with 2 batteries, charger and a 30-piece bit set.',
      rentPricePerDay: 800, deposit: 5000, purchasePrice: 32000, installmentMonths: 6, installmentMonthly: 5500, stock: 4, rating: 4.8, ratingCount: 5, rentalsCount: 12 }),
    tl({ name: 'Pipe Wrench Set (3 pcs)', category: 'plumbing', description: '10", 14" and 18" heavy-duty adjustable pipe wrenches.',
      rentPricePerDay: 300, deposit: 1500, purchasePrice: 6500, stock: 6, rentalsCount: 4 }),
    tl({ name: 'Manual Tile Cutter 24"', category: 'hand', description: 'Cuts ceramic and porcelain tiles up to 24 inches. Includes spare wheel.',
      rentPricePerDay: 600, deposit: 3000, purchasePrice: 14000, installmentMonths: 3, installmentMonthly: 4800, stock: 2, rating: 4.5, ratingCount: 2, rentalsCount: 3 }),
    tl({ name: 'Aluminium Extension Ladder 12 ft', category: 'ladders', description: 'Lightweight two-section ladder, 150 kg load rating.',
      rentPricePerDay: 500, deposit: 2500, purchasePrice: 18000, stock: 3, rating: 5, ratingCount: 1, rentalsCount: 6 }),
    tl({ name: 'Karcher Pressure Washer', category: 'cleaning', condition: 'like_new', description: '130 bar pressure washer for driveways, cars and terraces.',
      rentPricePerDay: 1500, deposit: 8000, purchasePrice: 45000, installmentMonths: 6, installmentMonthly: 7800, stock: 2, rating: 4.6, ratingCount: 3, rentalsCount: 7 }),
    tl({ name: 'Digital Multimeter', category: 'measurement', description: 'Auto-ranging multimeter with continuity buzzer and probes.',
      rentPricePerDay: 250, deposit: 1000, purchasePrice: 4500, stock: 5, rentalsCount: 2 }),
    tl({ name: 'Wet & Dry Vacuum 30L', category: 'cleaning', description: 'Industrial wet/dry vacuum with blower function.',
      rentPricePerDay: 900, deposit: 4000, purchasePrice: 26000, stock: 1, rentalsCount: 1 }),
    tl({ name: 'Angle Grinder 4.5"', category: 'power', description: '850W angle grinder with cutting and grinding discs. Safety glasses included.',
      rentPricePerDay: 700, deposit: 3000, purchasePrice: 12600, installmentMonths: 3, installmentMonthly: 4200, stock: 3, rentalsCount: 1 }),
    tl({ supplier: buildpro._id, city: 'Karachi', name: 'Concrete Mixer (half bag)', category: 'power', condition: 'fair', description: 'Electric drum mixer for small construction jobs. Delivery available.',
      rentPricePerDay: 3500, deposit: 15000, purchasePrice: 120000, stock: 1, rentalsCount: 2 }),
    tl({ supplier: buildpro._id, city: 'Karachi', name: 'Petrol Lawn Mower', category: 'gardening', description: 'Self-propelled 21" petrol mower with grass bag.',
      rentPricePerDay: 1200, deposit: 6000, purchasePrice: 55000, installmentMonths: 6, installmentMonthly: 9500, stock: 2 }),
    tl({ supplier: buildpro._id, city: 'Karachi', name: 'Self-levelling Laser Level', category: 'measurement', condition: 'new', description: 'Cross-line laser with tripod, ideal for tiling and shelving.',
      rentPricePerDay: 1000, deposit: 5000, purchasePrice: 28000, stock: 2 })
  ]);
  console.log(`Seeded ${tools.length} tools`);
  const [drill, , , ladder, washer, multimeter, , grinder] = tools;

  // --------------------------------------------------------------- rentals
  const rent = (o) => ({ supplier: toolco._id, type: 'rent', ...o });
  const [drillRental, , ladderRental] = await Rental.create([
    // Out with Sara right now, paid into escrow.
    rent({ tool: drill._id, renter: sara._id, days: 5, dailyRate: 800, startDate: ago(2 * DAY), endDate: ahead(3 * DAY), totalCost: 4000, deposit: 5000,
      payment: walletPay(4000, 'held', { deposit: 5000, heldAt: ago(2 * DAY + HOUR) }), status: 'active', approvedAt: ago(2 * DAY), fulfillment: 'pickup', createdAt: ago(2 * DAY + HOUR) }),
    // Waiting for the supplier's answer; delivery, cash.
    rent({ tool: washer._id, renter: bilal._id, days: 2, dailyRate: 1500, startDate: ahead(DAY), endDate: ahead(3 * DAY), totalCost: 3000, deposit: 8000,
      payment: cashPay(3000, 'cash_due', { deposit: 8000 }), status: 'requested', fulfillment: 'delivery',
      deliveryAddress: 'Flat 302, Block B, Gulshan-e-Iqbal, Karachi', note: 'Please deliver before 10am.', createdAt: ago(2 * HOUR) }),
    // Finished and reviewed.
    rent({ tool: ladder._id, renter: sara._id, days: 1, dailyRate: 500, startDate: ago(15 * DAY), endDate: ago(14 * DAY), totalCost: 500, deposit: 2500,
      payment: walletPay(500, 'released', { deposit: 2500, heldAt: ago(15 * DAY), settledAt: ago(14 * DAY) }), status: 'returned',
      approvedAt: ago(15 * DAY), returnedAt: ago(14 * DAY), rating: 5, review: 'Sturdy and clean. Easy pickup.', createdAt: ago(15 * DAY) }),
    // Overdue by a day (cash).
    rent({ tool: multimeter._id, renter: ahmad._id, days: 3, dailyRate: 250, startDate: ago(4 * DAY), endDate: ago(DAY), totalCost: 750, deposit: 1000,
      payment: cashPay(750, 'cash_due', { deposit: 1000 }), status: 'active', approvedAt: ago(4 * DAY), createdAt: ago(4 * DAY + HOUR) }),
    // Installment purchase waiting for approval.
    { tool: drill._id, renter: bilal._id, supplier: toolco._id, type: 'installment', totalCost: 32000, monthsTotal: 6, monthlyAmount: 5500,
      payment: cashPay(32000, 'none'), status: 'requested', fulfillment: 'delivery', deliveryAddress: 'Flat 302, Block B, Gulshan-e-Iqbal, Karachi', createdAt: ago(HOUR) },
    // Installment plan under way: 1 of 3 months paid.
    { tool: grinder._id, renter: ahmad._id, supplier: toolco._id, type: 'installment', totalCost: 12600, monthsTotal: 3, monthsPaid: 1, monthlyAmount: 4200,
      payment: { method: 'wallet', status: 'none', amount: 12600, net: 12600 }, status: 'active', approvedAt: ago(32 * DAY), fulfillment: 'pickup', createdAt: ago(33 * DAY) }
  ]);
  // Stock reflects what is out with customers.
  await Tool.updateOne({ _id: drill._id }, { $inc: { stock: -1 } });
  await Tool.updateOne({ _id: multimeter._id }, { $inc: { stock: -1 } });
  await Tool.updateOne({ _id: grinder._id }, { $inc: { stock: -1 } });

  move(sara, 'rental_hold', -3000, ago(15 * DAY), { rental: ladderRental._id, note: ladder.name });
  move(toolco, 'rental_earning', 500 - fee(500), ago(14 * DAY), { rental: ladderRental._id, note: ladder.name });
  move(null, 'platform_fee', fee(500), ago(14 * DAY), { rental: ladderRental._id, note: ladder.name });
  move(sara, 'rental_refund', 2500, ago(14 * DAY), { rental: ladderRental._id, note: `Deposit returned — ${ladder.name}` });
  move(sara, 'rental_hold', -9000, ago(2 * DAY + HOUR), { rental: drillRental._id, note: drill.name });
  move(ahmad, 'installment_payment', -4200, ago(31 * DAY), { note: grinder.name });
  move(toolco, 'installment_earning', 4200 - fee(4200), ago(31 * DAY), { note: grinder.name });
  move(null, 'platform_fee', fee(4200), ago(31 * DAY), { note: grinder.name });
  move(usman, 'withdrawal', -20000, ago(6 * DAY), { note: 'Withdrawal to HBL · 0042-79118812-01' });
  move(ahmad, 'withdrawal', -3000, ago(5 * HOUR), { note: 'Withdrawal to Easypaisa · 0300-1234503' });
  console.log('Seeded 6 rentals and installment plans');

  // ---------------------------------------------------------------- wallets
  ledger.sort((a, b) => a.createdAt - b.createdAt);
  const balances = new Map();
  const autoDeposits = [];
  for (const row of ledger) {
    if (!row.user) continue;
    const key = String(row.user);
    // A wallet can't go negative: top it up first if history would overdraw it.
    if ((balances.get(key) || 0) + row.amount < 0) {
      const short = Math.ceil(-((balances.get(key) || 0) + row.amount) / 5000) * 5000;
      balances.set(key, (balances.get(key) || 0) + short);
      const at = new Date(row.createdAt.getTime() - HOUR);
      const tx = `MZ${String(at.getTime()).slice(-8)}`;
      await Transaction.create({ user: row.user, type: 'deposit', amount: short, balanceAfter: balances.get(key), note: `Meezan Bank · TX ${tx}`, createdAt: at });
      autoDeposits.push({ user: row.user, amount: short, at, tx });
    }
    balances.set(key, (balances.get(key) || 0) + row.amount);
    row.balanceAfter = balances.get(key);
  }
  await Transaction.insertMany(ledger);
  await Promise.all([...balances].map(([id, balance]) => User.updateOne({ _id: id }, { $set: { walletBalance: balance } })));
  console.log(`Seeded ${ledger.length} wallet transactions`);

  // ---------------------------------------- company accounts & wallet requests
  // Demo details: an admin replaces them in Payments → Company accounts.
  const [meezan, jazzcash, easypaisa] = await PaymentAccount.create([
    { kind: 'bank', provider: 'Meezan Bank', accountTitle: 'SureFix Services', accountNumber: '0101-0104567890', iban: 'PK36MEZN0001010104567890',
      instructions: 'Demo account. Use your name as the transfer reference.', order: 1 },
    { kind: 'mobile_wallet', provider: 'JazzCash', accountTitle: 'SureFix Services', accountNumber: '0300-1112233', order: 2 },
    { kind: 'mobile_wallet', provider: 'Easypaisa', accountTitle: 'SureFix Services', accountNumber: '0345-4445566', order: 3 }
  ]);
  const snap = (a) => ({ method: a.kind, provider: a.provider, accountTitle: a.accountTitle, accountNumber: a.accountNumber });
  const dep = (user, account, amount, tx, at, extra = {}) => ({
    user: user._id || user, kind: 'deposit', amount, companyAccount: account._id, sentTo: snap(account), transactionId: tx,
    transactionKey: WalletRequest.normalizeTx(tx), createdAt: at, ...extra
  });
  const approved = (at) => ({ status: 'approved', reviewedBy: admin._id, reviewedAt: new Date(at.getTime() + 2 * HOUR) });
  const usmanPayout = { method: 'bank', provider: 'HBL', accountTitle: 'Usman Ali', accountNumber: '0042-79118812-01' };
  const ahmadPayout = { method: 'mobile_wallet', provider: 'Easypaisa', accountTitle: 'Ahmad Raza', accountNumber: '0300-1234503' };
  await WalletRequest.create([
    dep(sara, meezan, 20000, 'MZ88120345', ago(30 * DAY), approved(ago(30 * DAY))),
    dep(sara, jazzcash, 10000, 'JC51200987', ago(3 * DAY), approved(ago(3 * DAY))),
    ...autoDeposits.map((d) => dep(d.user, meezan, d.amount, d.tx, d.at, approved(d.at))),
    dep(sara, easypaisa, 2000, 'EP77001234', ago(8 * DAY), {
      status: 'rejected', adminNote: 'We could not find this transaction ID in our statement.', reviewedBy: admin._id, reviewedAt: ago(8 * DAY - 3 * HOUR)
    }),
    // Waiting for the admin:
    dep(bilal, jazzcash, 5000, 'JC48213977', ago(2 * HOUR), { note: 'Sent from my JazzCash at 2:15 pm' }),
    { user: ahmad._id, kind: 'withdrawal', amount: 3000, payout: ahmadPayout, createdAt: ago(5 * HOUR) },
    { user: usman._id, kind: 'withdrawal', amount: 20000, payout: usmanPayout, reference: 'HBL-FT-55120931', createdAt: ago(6 * DAY), ...approved(ago(6 * DAY)) }
  ]);
  await User.updateOne({ _id: usman._id }, { $set: { payoutAccount: usmanPayout } });
  await User.updateOne({ _id: ahmad._id }, { $set: { payoutAccount: ahmadPayout } });
  console.log('Seeded company accounts, deposits and withdrawals (1 deposit + 1 withdrawal waiting for review)');

  await User.updateOne({ _id: sara._id }, { $set: { favoriteTechnicians: [usman._id, ayesha._id], favoriteTools: [drill._id, washer._id] } });

  // -------------------------------------------------------------- messages
  const m = (ref, from, to, text, at, read = true) => ({ ...ref, sender: from._id, recipient: to._id, text, createdAt: at, readAt: read ? at : null });
  const acChat = { job: ac._id };
  const sinkChat = { job: sink._id };
  const drillChat = { tool: drill._id };
  await Message.create([
    m(acChat, sara, usman, 'Hi Usman, is the gas refill included in the 6000?', ago(DAY + 19 * HOUR)),
    m(acChat, usman, sara, 'Yes, refill plus a full indoor and outdoor unit service.', ago(DAY + 18.5 * HOUR)),
    m(acChat, sara, usman, 'Great. Can you come tomorrow at 11?', ago(DAY + 18 * HOUR)),
    m(acChat, usman, sara, 'Confirmed for 11am. I will bring the gas cylinder.', ago(DAY + 17 * HOUR)),
    m(acChat, usman, sara, 'On my way, 15 minutes out.', ago(50 * MIN), false),
    m(sinkChat, sara, ahmad, 'Do you have the fittings for a 1/2" pipe?', ago(4 * HOUR)),
    m(sinkChat, ahmad, sara, 'Yes, I carry standard 1/2" and 3/4" fittings in the van.', ago(3.8 * HOUR), false),
    // Customer ↔ supplier chat about a tool (arranging pickup).
    m(drillChat, sara, toolco, 'Hi, does the drill come with masonry bits?', ago(2 * DAY + 2 * HOUR)),
    m(drillChat, toolco, sara, 'Yes — a 5-piece masonry set and two batteries are included.', ago(2 * DAY + 1.5 * HOUR)),
    m(drillChat, sara, toolco, 'Great, I will pick it up around 6pm today.', ago(2 * DAY + HOUR)),
    m(drillChat, toolco, sara, 'Perfect. Ask for Kamran at the counter, Shop 12.', ago(2 * DAY + 0.5 * HOUR))
  ]);

  const note = (user, type, title, body, data, at, read = false) => ({ user: user._id, type, title, body, data, createdAt: at, readAt: read ? at : null });
  await Notification.create([
    note(sara, 'job_status', 'Work finished — please confirm', `Ahmad Raza finished "${socket.title}". Please confirm so they get paid.`, { jobId: socket._id }, ago(3 * HOUR)),
    note(sara, 'job_status', 'Work started', `Usman Ali: work started — "${ac.title}"`, { jobId: ac._id }, ago(20 * MIN)),
    note(sara, 'bid', 'New quote on your job', `Noor Fatima quoted 3200 for "${sink.title}"`, { jobId: sink._id }, ago(2 * HOUR), true),
    note(sara, 'rental', 'Your rental was approved', `Collect "${drill.name}" from Shop 12, Hall Road Tool Market, Lahore`, { rentalId: drillRental._id, toolId: drill._id }, ago(2 * DAY), true),
    note(ahmad, 'request', 'New service request', `Bilal Ahmed requested you for "${dbBox.title}"`, { jobId: dbBox._id }, ago(3 * HOUR)),
    note(ahmad, 'review', 'New 5★ review', 'Quick, tidy and explained everything. Highly recommended!', { jobId: tap._id }, ago(10 * DAY), true),
    note(usman, 'job_status', 'You got the job!', `You were hired for "${ac.title}"`, { jobId: ac._id }, ago(DAY + 20 * HOUR), true),
    note(toolco, 'rental', 'New rental request', `Bilal Ahmed wants "${washer.name}" for 2 days`, { toolId: washer._id }, ago(2 * HOUR)),
    note(toolco, 'rental', 'New purchase request', `Bilal Ahmed wants to buy "${drill.name}" on installments`, { toolId: drill._id }, ago(HOUR))
  ]);

  await Kyc.create({ user: zainab._id, fullName: 'Zainab Hussain', idType: 'cnic', idNumber: '35202-1234567-8', status: 'pending' });
  await Report.create({
    reporter: bilal._id, targetType: 'user', targetId: hamza._id, targetLabel: 'Hamza Sheikh (technician)',
    reason: 'no_show', details: 'Agreed on a visit time and never showed up or answered calls.'
  });
  console.log('Seeded chats, notifications, 1 verification request, 1 report');

  // -------------------------------------------------------------- locations
  // Everyone gets a place near a real neighbourhood (slightly off its centre)
  // so "near me" search and distances work out of the box. Tools sit at their
  // supplier's shop; jobs at their client's home.
  const { AREAS } = require('../config/areas');
  const { point } = require('../utils/geo');
  const placeOf = (city, name, dLat = 0.004, dLng = -0.003) => {
    const a = AREAS.find((x) => x.city === city && x.name === name);
    return { geo: point(a.lat + dLat, a.lng + dLng), area: a.name };
  };
  const places = [
    [sara, placeOf('Lahore', 'DHA Phase 4')],
    [bilal, placeOf('Karachi', 'Gulshan-e-Iqbal')],
    [ahmad, { ...placeOf('Lahore', 'Model Town', -0.002, 0.004), serviceRadiusKm: 15 }],
    [noor, { ...placeOf('Lahore', 'Gulberg', 0.003, 0.002), serviceRadiusKm: 12 }],
    [usman, { ...placeOf('Lahore', 'DHA Phase 5', -0.003, -0.004), serviceRadiusKm: 20 }],
    [zainab, { ...placeOf('Islamabad', 'F-7'), serviceRadiusKm: 15 }],
    [hamza, { ...placeOf('Karachi', 'PECHS'), serviceRadiusKm: 15 }],
    [ayesha, { ...placeOf('Lahore', 'Johar Town', 0.002, 0.003), serviceRadiusKm: 10 }],
    [farhan, { ...placeOf('Lahore', 'Bahria Town'), serviceRadiusKm: 8 }],
    [imran, { ...placeOf('Rawalpindi', 'Satellite Town'), serviceRadiusKm: 20 }],
    [toolco, placeOf('Lahore', 'Garden Town', 0.001, 0.002)],
    [buildpro, placeOf('Karachi', 'Clifton')]
  ];
  for (const [user, place] of places) await User.updateOne({ _id: user._id }, { $set: place });
  for (const [supplier, place] of [[toolco, places[10][1]], [buildpro, places[11][1]]]) {
    await Tool.updateMany({ supplier: supplier._id }, { $set: { geo: place.geo, area: place.area } });
  }
  for (const [client, place] of [[sara, places[0][1]], [bilal, places[1][1]]]) {
    await Job.updateMany({ client: client._id }, { $set: { geo: place.geo, area: place.area } });
  }
  console.log('Seeded locations for people, tools and jobs');

  console.log('\nDemo accounts (password: password123):');
  [sara, bilal, ahmad, usman, toolco, admin].forEach((x) => console.log(`  ${x.role.padEnd(10)} ${x.email}`));
  await mongoose.disconnect();
  console.log('Done.');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
