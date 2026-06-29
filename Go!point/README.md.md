# Go!Point - Food Delivery Platform

A modern food delivery application for Somaliland, built with HTML/CSS/JS, Supabase backend, and hosted on Vercel.

## 🌐 Live Demo
**https://gopoint.vercel.app**

## 🚀 Features

- **Location Gate**: Mandatory GPS permission for accurate delivery
- **Restaurant Explorer**: Browse restaurants and menus
- **Smart Checkout**: Medium modal with auto-detected location
- **Live Tracking**: Kicki Drop-style real-time order tracking
- **Management Dashboard**: Orders, fleet, analytics
- **Payment Methods**: Telesom, E-Dahab, Cash
- **Real-time Sync**: Supabase Realtime subscriptions

## 📦 Tech Stack

- **Frontend**: HTML5, Tailwind CSS, Vanilla JavaScript
- **Backend**: Supabase (PostgreSQL + Realtime + Auth)
- **Maps**: Leaflet.js + OpenStreetMap
- **Hosting**: Vercel
- **Icons**: Font Awesome 6

## 🛠️ Setup Instructions

### 1. Supabase Setup

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Once created, go to **Project Settings → API** and copy:
   - **Project URL** (e.g., `https://abcdefghij.supabase.co`)
   - **anon/public key** (starts with `eyJ...`)
3. Go to **SQL Editor** and paste the contents of `supabase-schema.sql`
4. Click **Run** to create all tables, indexes, and RLS policies
5. Go to **Database → Replication** and enable Realtime for all 4 tables:
   - `restaurants`
   - `vehicles`
   - `orders`
   - `settings`

### 2. Configure Credentials

Edit `config.js` and replace the placeholders:

```javascript
window.SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';
window.SUPABASE_ANON_KEY = 'YOUR_ANON_KEY_HERE';