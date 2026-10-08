require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');
const Job = require('../models/Job');
const Tool = require('../models/Tool');

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/fixit';

async function run() {
  await mongoose.connect(MONGO_URI);
  console.log('Connected. Wiping demo collections…');

  await Promise.all([
    User.deleteMany({}),
    Job.deleteMany({}),
    Tool.deleteMany({})
  ]);

  const [client, tech, tech2, supplier, admin] = await User.create([
    { name: 'Sara Client', email: 'client@demo.com', password: 'password123', role: 'client', phone: '555-0101' },
    { name: 'Ahmad Tech',  email: 'tech@demo.com',   password: 'password123', role: 'technician', phone: '555-0102',
      skills: ['plumbing', 'electrical'], rating: 4.6, ratingCount: 12, jobsCompleted: 14, jobsAssigned: 15, avgResponseMinutes: 22,
      bio: 'Licensed electrician, 8 yrs exp.', kycStatus: 'approved' },
    { name: 'Noor Fix',    email: 'tech2@demo.com',  password: 'password123', role: 'technician', phone: '555-0103',
      skills: ['carpentry'], rating: 4.1, ratingCount: 6, jobsCompleted: 7, jobsAssigned: 9, avgResponseMinutes: 45,
      bio: 'Carpenter & handyman.', kycStatus: 'approved' },
    { name: 'ToolCo',      email: 'supplier@demo.com', password: 'password123', role: 'supplier', phone: '555-0104' },
    { name: 'Admin',       email: 'admin@demo.com',  password: 'password123', role: 'admin' }
  ]);

  console.log('Seeded users:');
  [client, tech, tech2, supplier, admin].forEach((u) => console.log(` - ${u.role.padEnd(10)} ${u.email}`));

  await Job.create([
    {
      client: client._id,
      title: 'Fix leaking kitchen sink',
      description: 'Water drips from below, need quick fix today if possible.',
      category: 'plumbing',
      budget: 80,
      location: 'Apt 3B, Downtown',
      status: 'pending',
      bids: [
        { technician: tech._id, amount: 75, message: 'Can do this afternoon.', etaDays: 1 },
        { technician: tech2._id, amount: 90, message: 'Available tomorrow.',  etaDays: 2 }
      ]
    },
    {
      client: client._id,
      title: 'Install ceiling fan',
      description: 'Bedroom ceiling fan, wiring already in place.',
      category: 'electrical',
      budget: 120,
      location: 'Apt 3B, Downtown',
      status: 'pending'
    }
  ]);
  console.log('Seeded 2 jobs with sample bids.');

  await Tool.create([
    {
      supplier: supplier._id,
      name: 'Bosch Cordless Drill',
      description: '18V cordless drill with 2 batteries.',
      category: 'power',
      rentPricePerDay: 8,
      purchasePrice: 160,
      installmentMonths: 6,
      installmentMonthly: 30,
      stock: 5
    },
    {
      supplier: supplier._id,
      name: 'Pipe Wrench Set',
      description: 'Set of 3 adjustable pipe wrenches.',
      category: 'hand',
      rentPricePerDay: 3,
      purchasePrice: 45,
      installmentMonths: 0,
      stock: 8
    },
    {
      supplier: supplier._id,
      name: 'Tile Cutter',
      description: 'Manual tile cutter, up to 24".',
      category: 'hand',
      rentPricePerDay: 6,
      purchasePrice: 95,
      installmentMonths: 3,
      installmentMonthly: 35,
      stock: 3
    }
  ]);
  console.log('Seeded 3 tools.');

  await mongoose.disconnect();
  console.log('Done.');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
