/// Words shared by the public website and the in-app help screens.
library;

const faqs = [
  (
    'How does SureFix work?',
    'Describe what needs fixing and post it as a job. Verified technicians nearby send you quotes; our AI ranks them and explains why each one fits. '
        'Pick one, follow their progress live, and confirm when the work is done.'
  ),
  (
    'How do payments and escrow work?',
    'When you hire with the SureFix Wallet, the agreed price moves into escrow: it leaves your wallet but is not paid to the technician yet. '
        'It is released only when you confirm the job is complete. If the job is cancelled before work starts, or the technician withdraws, you get it all back. '
        'You can also choose to pay cash in person.'
  ),
  (
    'What if the work is finished but I am not happy?',
    'Do not confirm the job. Use "Report a problem" on the job page and the SureFix team will review it; they can refund your payment or release it to the technician. '
        'If you do nothing for 72 hours after the technician marks the work finished, they may close the job themselves.'
  ),
  (
    'What does it cost?',
    'Posting jobs and getting quotes is free. SureFix keeps a 10% service fee from wallet payments when a job or rental completes; technicians and suppliers see exactly what they will receive before they accept. '
        'Cash payments have no fee.'
  ),
  (
    'How does tool rental work?',
    'Choose a tool, pick your dates, and choose pickup or delivery. The supplier approves the request and you get the handover address and their phone number. '
        'A refundable deposit covers late returns: each late day costs one day of rent, taken from the deposit. Some tools can also be bought in monthly installments.'
  ),
  (
    'How are technicians verified?',
    'Technicians and suppliers submit a government ID and a selfie. An admin reviews them, and approved accounts show a blue verified seal. '
        'Ratings and reviews come only from customers whose job was completed through SureFix.'
  ),
  (
    'Is the money real?',
    'No. This is a final-year project: the wallet is a sandbox, top-ups add demo funds and withdrawals simply reduce the balance. The escrow rules, fees and ledger work exactly as they would with a real payment provider.'
  ),
];

const termsSections = [
  (
    'Using SureFix',
    'SureFix connects customers with independent technicians and tool suppliers. You must give accurate information, keep your password private, and use the marketplace lawfully and respectfully.'
  ),
  (
    'Jobs and quotes',
    'A quote is an offer to do the described work for the stated price. Hiring a technician creates an agreement between the customer and that technician. Either side may withdraw before work starts; after that, problems go through SureFix support.'
  ),
  (
    'Payments',
    'Wallet payments are held in escrow and released when the customer confirms completion, when an admin resolves a dispute, or when the customer has not responded 72 hours after the work was marked finished. SureFix keeps a service fee from released payments. In this project build all funds are simulated.'
  ),
  (
    'Tool rentals',
    'Renters must return tools on time and in the condition received. Deposits cover late fees of one daily rate per late day, up to the deposit. Suppliers must describe tools honestly and hand them over as agreed.'
  ),
  ('Reviews and conduct', 'Reviews must reflect real experiences. Harassment, fraud, off-platform payment requests to avoid fees, and fake listings lead to suspension.'),
  ('Accounts', 'Admins may suspend accounts that break these terms. You may ask for your account to be removed once you have no job in progress and no tool out on rent.'),
];

const privacySections = [
  (
    'What we store',
    'Your profile (name, email, phone, city, address), the jobs, quotes, rentals, messages and reviews you create, wallet transactions, and — if you verify your identity — the ID details and photos you submit.'
  ),
  (
    'Who sees what',
    'Your public profile shows your name, city, skills, ratings and portfolio. Phone numbers and addresses are shared only between a customer and the technician they hired, or between a renter and supplier once a rental is approved. ID documents are visible only to admins.'
  ),
  (
    'How it is used',
    'To run the marketplace: matching and ranking technicians, sending notifications, resolving disputes and preventing abuse. The AI ranking uses marketplace data only — skills, ratings, completion rate, response time, distance and price.'
  ),
  ('Security', 'Passwords are stored hashed, never in plain text. Sessions use signed tokens that expire. Uploaded files are limited to images.'),
  ('Your choices', 'You can edit your profile at any time, and ask an admin to delete your account and its data.'),
];
