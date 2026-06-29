-- ============================================================
-- GOPoint Database Schema
-- ============================================================

-- Drop existing tables if needed (careful in production!)
-- DROP TABLE IF EXISTS orders;
-- DROP TABLE IF EXISTS vehicles;
-- DROP TABLE IF EXISTS restaurants;
-- DROP TABLE IF EXISTS settings;

-- RESTAURANTS TABLE
CREATE TABLE IF NOT EXISTS restaurants (
  key TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  email TEXT,
  logo TEXT,
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  rating DOUBLE PRECISION DEFAULT 4.5,
  delivery_time TEXT DEFAULT '20 min',
  delivery_fee TEXT DEFAULT '$2',
  cuisine TEXT,
  menu JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- VEHICLES TABLE
CREATE TABLE IF NOT EXISTS vehicles (
  id BIGSERIAL PRIMARY KEY,
  type TEXT NOT NULL CHECK (type IN ('bike', 'taxi')),
  plate_number TEXT NOT NULL,
  driver_name TEXT NOT NULL,
  driver_phone TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'delivering', 'unavailable')),
  lat DOUBLE PRECISION DEFAULT 9.56,
  lng DOUBLE PRECISION DEFAULT 44.06,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ORDERS TABLE
CREATE TABLE IF NOT EXISTS orders (
  id BIGSERIAL PRIMARY KEY,
  type TEXT DEFAULT 'delivery',
  customer JSONB,
  payment JSONB,
  items JSONB,
  total NUMERIC(10, 2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'preparing', 'ready', 'out_for_delivery', 'completed', 'cancelled')),
  coordinates JSONB,
  restaurant TEXT,
  vehicle JSONB,
  status_history JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- SETTINGS TABLE
CREATE TABLE IF NOT EXISTS settings (
  id TEXT PRIMARY KEY DEFAULT 'app',
  data JSONB DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES (for performance)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vehicles_status ON vehicles(status);
CREATE INDEX IF NOT EXISTS idx_restaurants_key ON restaurants(key);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

-- Allow public read access to restaurants
CREATE POLICY "Public can view restaurants" ON restaurants
  FOR SELECT USING (true);

-- Allow public read access to vehicles
CREATE POLICY "Public can view vehicles" ON vehicles
  FOR SELECT USING (true);

-- Allow public read access to orders (for tracking)
CREATE POLICY "Public can view orders" ON orders
  FOR SELECT USING (true);

-- Allow public read access to settings
CREATE POLICY "Public can view settings" ON settings
  FOR SELECT USING (true);

-- Allow public insert for orders (customers placing orders)
CREATE POLICY "Public can insert orders" ON orders
  FOR INSERT WITH CHECK (true);

-- Allow public update for orders (status changes)
CREATE POLICY "Public can update orders" ON orders
  FOR UPDATE USING (true);

-- Allow public insert for restaurants (admin adds via UI)
CREATE POLICY "Public can insert restaurants" ON restaurants
  FOR INSERT WITH CHECK (true);

-- Allow public update for restaurants
CREATE POLICY "Public can update restaurants" ON restaurants
  FOR UPDATE USING (true);

-- Allow public insert for vehicles
CREATE POLICY "Public can insert vehicles" ON vehicles
  FOR INSERT WITH CHECK (true);

-- Allow public update for vehicles
CREATE POLICY "Public can update vehicles" ON vehicles
  FOR UPDATE USING (true);

-- Allow public insert for settings
CREATE POLICY "Public can insert settings" ON settings
  FOR INSERT WITH CHECK (true);

-- Allow public update for settings
CREATE POLICY "Public can update settings" ON settings
  FOR UPDATE USING (true);

-- ============================================================
-- REALTIME (enable for all tables)
-- ============================================================
-- In Supabase dashboard: Database → Replication → enable for all 4 tables
-- Or via SQL:
ALTER PUBLICATION supabase_realtime ADD TABLE restaurants;
ALTER PUBLICATION supabase_realtime ADD TABLE vehicles;
ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE settings;

-- ============================================================
-- AUTO-UPDATE updated_at TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_settings_updated_at
  BEFORE UPDATE ON settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();