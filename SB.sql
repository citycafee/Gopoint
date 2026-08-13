-- ============================================================
-- Go!point — Supabase Database Schema + Seed Data
-- Project: tsuhzwqrduluzbxmdoxq
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- ─────────────────────────────────────────────
-- CLEAN SLATE — drop old tables if they exist
-- (order matters: drop children first)
-- ─────────────────────────────────────────────
DROP TABLE IF EXISTS orders      CASCADE;
DROP TABLE IF EXISTS menu_items  CASCADE;
DROP TABLE IF EXISTS vehicles    CASCADE;
DROP TABLE IF EXISTS restaurants CASCADE;
DROP TABLE IF EXISTS settings    CASCADE;
DROP TABLE IF EXISTS profiles    CASCADE;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- ─────────────────────────────────────────────
-- EXTENSIONS
-- ─────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ═══════════════════════════════════════════════
-- TABLES
-- ═══════════════════════════════════════════════

-- 1. PROFILES (extends Supabase auth.users)
CREATE TABLE profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name  TEXT NOT NULL DEFAULT '',
  phone      TEXT DEFAULT '',
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. RESTAURANTS
CREATE TABLE restaurants (
  id                TEXT PRIMARY KEY,
  name              TEXT NOT NULL,
  address           TEXT DEFAULT '',
  phone             TEXT DEFAULT '',
  email             TEXT DEFAULT '',
  lat               NUMERIC DEFAULT 9.56,
  lng               NUMERIC DEFAULT 44.065,
  rating            NUMERIC DEFAULT 4.5,
  delivery_time     TEXT DEFAULT '20 min',
  delivery_fee      TEXT DEFAULT '$2',
  cuisine           TEXT DEFAULT 'Various',
  logo_url          TEXT,
  active_categories TEXT[] DEFAULT ARRAY['food','juices','softdrinks','coffee','dessert'],
  active            BOOLEAN DEFAULT true,
  created_at        TIMESTAMPTZ DEFAULT now()
);

-- 3. MENU ITEMS
CREATE TABLE menu_items (
  id              BIGSERIAL PRIMARY KEY,
  restaurant_id   TEXT NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  category        TEXT NOT NULL CHECK (category IN ('food','coffee','dessert','juices','softdrinks')),
  name            TEXT NOT NULL,
  price           NUMERIC NOT NULL DEFAULT 0,
  description     TEXT DEFAULT '',
  image_url       TEXT DEFAULT '',
  sort_order      INT DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_menu_items_restaurant ON menu_items(restaurant_id);

-- 4. VEHICLES / FLEET
CREATE TABLE vehicles (
  id            TEXT PRIMARY KEY,
  type          TEXT NOT NULL DEFAULT 'bike' CHECK (type IN ('bike','taxi')),
  plate_number  TEXT NOT NULL,
  model         TEXT DEFAULT '',
  driver_name   TEXT NOT NULL,
  driver_phone  TEXT NOT NULL,
  driver_pin    TEXT NOT NULL,
  license       TEXT DEFAULT '',
  status        TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available','unavailable','delivering')),
  lat           NUMERIC DEFAULT 9.56,
  lng           NUMERIC DEFAULT 44.065,
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- 5. ORDERS
CREATE TABLE orders (
  id                TEXT PRIMARY KEY,
  customer_name     TEXT DEFAULT '',
  customer_phone    TEXT DEFAULT '',
  customer_address  TEXT DEFAULT '',
  customer_area     TEXT DEFAULT '',
  coordinates       JSONB DEFAULT '{"lat":9.56,"lng":44.065}',
  restaurant_id     TEXT REFERENCES restaurants(id),
  items             JSONB DEFAULT '[]',
  total             NUMERIC DEFAULT 0,
  status            TEXT DEFAULT 'pending'
                    CHECK (status IN ('pending','preparing','ready','out_for_delivery','completed','cancelled')),
  payment_method    TEXT DEFAULT 'cash',
  payment_phone     TEXT DEFAULT '',
  vehicle_id        TEXT REFERENCES vehicles(id),
  vehicle_snapshot  JSONB,
  status_history    JSONB DEFAULT '[]',
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_orders_status     ON orders(status);
CREATE INDEX idx_orders_restaurant ON orders(restaurant_id);
CREATE INDEX idx_orders_vehicle    ON orders(vehicle_id);
CREATE INDEX idx_orders_created    ON orders(created_at);

-- 6. SETTINGS
CREATE TABLE settings (
  key        TEXT PRIMARY KEY,
  value      JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ═══════════════════════════════════════════════
-- TRIGGER: auto-create profile on signup
-- ═══════════════════════════════════════════════
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, full_name, phone)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'phone', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ═══════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS)
-- ═══════════════════════════════════════════════
ALTER TABLE profiles    ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items  ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles    ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders      ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings    ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles: public read"     ON profiles    FOR SELECT USING (true);
CREATE POLICY "Profiles: user update own" ON profiles    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Restaurants: public read"  ON restaurants FOR SELECT USING (true);
CREATE POLICY "Restaurants: anyone insert" ON restaurants FOR INSERT WITH CHECK (true);
CREATE POLICY "Restaurants: anyone update" ON restaurants FOR UPDATE USING (true);
CREATE POLICY "Restaurants: anyone delete" ON restaurants FOR DELETE USING (true);

CREATE POLICY "Menu: public read"         ON menu_items  FOR SELECT USING (true);
CREATE POLICY "Menu: anyone insert"       ON menu_items  FOR INSERT WITH CHECK (true);
CREATE POLICY "Menu: anyone update"       ON menu_items  FOR UPDATE USING (true);
CREATE POLICY "Menu: anyone delete"       ON menu_items  FOR DELETE USING (true);

CREATE POLICY "Vehicles: public read"     ON vehicles    FOR SELECT USING (true);
CREATE POLICY "Vehicles: anyone insert"   ON vehicles    FOR INSERT WITH CHECK (true);
CREATE POLICY "Vehicles: anyone update"   ON vehicles    FOR UPDATE USING (true);
CREATE POLICY "Vehicles: anyone delete"   ON vehicles    FOR DELETE USING (true);

CREATE POLICY "Orders: public read"       ON orders      FOR SELECT USING (true);
CREATE POLICY "Orders: anyone insert"     ON orders      FOR INSERT WITH CHECK (true);
CREATE POLICY "Orders: anyone update"     ON orders      FOR UPDATE USING (true);
CREATE POLICY "Orders: anyone delete"     ON orders      FOR DELETE USING (true);

CREATE POLICY "Settings: public read"     ON settings    FOR SELECT USING (true);
CREATE POLICY "Settings: anyone insert"   ON settings    FOR INSERT WITH CHECK (true);
CREATE POLICY "Settings: anyone update"   ON settings    FOR UPDATE USING (true);

-- ═══════════════════════════════════════════════
-- ENABLE REALTIME
-- ═══════════════════════════════════════════════
ALTER PUBLICATION supabase_realtime ADD TABLE orders;

-- ═══════════════════════════════════════════════
-- SEED DATA
-- ═══════════════════════════════════════════════

INSERT INTO restaurants (id, name, address, phone, lat, lng, rating, delivery_time, delivery_fee, cuisine, active_categories, active)
VALUES
  ('damal-restaurant',  'Damal Restaurant',  'Downtown, Hargeisa',        '+252 61 1234567', 9.5600, 44.0650, 4.8, '25 min', '$2',   'Mediterranean', ARRAY['food','coffee'],                         true),
  ('hiddo-dhowr-pizza', 'Hiddo Dhowr Pizza', 'Main Street, Hargeisa',     '+252 61 2345678', 9.5620, 44.0680, 4.9, '20 min', '$1.5', 'Italian',       ARRAY['food','juices','softdrinks','coffee','dessert'], true),
  ('burger-house',      'Burger House',      'Central Market, Hargeisa',  '+252 61 3456789', 9.5580, 44.0620, 4.7, '18 min', '$2',   'Fast Food',     ARRAY['juices','softdrinks'],                  true),
  ('som-coffee',        'Som Coffee',        'University Road, Hargeisa', '+252 61 4567890', 9.5640, 44.0700, 4.9, '15 min', '$1',   'Cafe',          ARRAY['coffee','dessert','juices'],             true);

INSERT INTO menu_items (restaurant_id, category, name, price, description, image_url, sort_order)
VALUES
  ('damal-restaurant', 'coffee', 'Espresso',          3.50,  'Rich & bold single shot',            'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=200&h=200&fit=crop', 1),
  ('damal-restaurant', 'coffee', 'Cappuccino',        4.25,  'Espresso with steamed milk foam',     'https://images.unsplash.com/photo-1485808191679-5f86510681a2?w=200&h=200&fit=crop', 2),
  ('damal-restaurant', 'food',   'Signature Burger',  12.90, 'Grilled beef, cheddar, fresh veggies','https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200&h=200&fit=crop', 1),
  ('damal-restaurant', 'food',   'Truffle Pasta',     14.50, 'Creamy mushroom truffle sauce',       'https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=200&h=200&fit=crop', 2),

  ('hiddo-dhowr-pizza','food',   'Margherita Pizza',  10.50, 'Classic tomato, mozzarella, basil',   'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=200&h=200&fit=crop', 1),
  ('hiddo-dhowr-pizza','food',   'Pepperoni Pizza',   12.90, 'Loaded with pepperoni',               'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=200&h=200&fit=crop', 2),

  ('burger-house',     'food',   'Classic Burger',     9.90, 'Beef patty, lettuce, tomato',         'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200&h=200&fit=crop', 1),
  ('burger-house',     'food',   'Double Cheese Burger',13.50,'Double patty with extra cheese',      'https://images.unsplash.com/photo-1550547660-d9450f859349?w=200&h=200&fit=crop', 2),

  ('som-coffee',       'coffee', 'Somali Spiced Coffee',4.00,'Traditional cardamom & clove',         'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=200&h=200&fit=crop', 1),
  ('som-coffee',       'coffee', 'Iced Latte',          4.50,'Cold espresso with milk',              'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=200&h=200&fit=crop', 2);

INSERT INTO vehicles (id, type, plate_number, driver_name, driver_phone, driver_pin, status, lat, lng)
VALUES
  ('v1', 'bike', 'B1234', 'Ahmed Ali',      '+252631112222', '1234', 'available',  9.5650, 44.0700),
  ('v2', 'taxi', 'T5678', 'Mohamed Hassan', '+252653334444', '2345', 'available',  9.5550, 44.0550),
  ('v3', 'bike', 'B9012', 'Abdi Karim',     '+252635556666', '3456', 'delivering', 9.5700, 44.0600),
  ('v4', 'taxi', 'T2468', 'Fatima Omar',    '+252657778888', '4567', 'available',  9.5610, 44.0660),
  ('v5', 'bike', 'B3456', 'Hanad',           '+252610000000', '1111', 'available',  9.5600, 44.0650);

INSERT INTO settings (key, value)
VALUES
  ('system',   '{"businessName":"Go!Point","businessAddress":"Hargeisa, Somaliland","businessPhone":"+252 61 XXX XXXX","businessEmail":"info@gopoint.com","minOrder":10,"defaultOrder":"delivery"}'::jsonb),
  ('delivery', '{"motorcycleDelivery":true,"taxiDelivery":true,"maxDistance":10,"baseFee":2.50,"perKmFee":0.50,"startTime":"08:00","endTime":"22:00"}'::jsonb);

-- ═══════════════════════════════════════════════
-- DONE
-- Tables: profiles, restaurants, menu_items, vehicles, orders, settings
-- Seed:  4 restaurants, 10 menu items, 5 drivers, 2 settings
-- ═══════════════════════════════════════════════
