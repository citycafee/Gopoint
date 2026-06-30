-- Restaurants table
CREATE TABLE restaurants (
  id TEXT PRIMARY KEY,
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
  menu JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Vehicles table
CREATE TABLE vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL,
  plate_number TEXT NOT NULL,
  driver_name TEXT NOT NULL,
  driver_phone TEXT,
  status TEXT DEFAULT 'available',
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Orders table
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT DEFAULT 'delivery',
  customer JSONB,
  payment JSONB,
  items JSONB,
  total DOUBLE PRECISION,
  status TEXT DEFAULT 'pending',
  coordinates JSONB,
  restaurant TEXT,
  vehicle JSONB,
  status_history JSONB DEFAULT '[]',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Settings table
CREATE TABLE settings (
  id TEXT PRIMARY KEY DEFAULT 'app',
  system JSONB,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security (optional for development)
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

-- Create policies for public access (development)
CREATE POLICY "Public access" ON restaurants FOR ALL USING (true);
CREATE POLICY "Public access" ON vehicles FOR ALL USING (true);
CREATE POLICY "Public access" ON orders FOR ALL USING (true);
CREATE POLICY "Public access" ON settings FOR ALL USING (true);

-- Enable realtime for all tables
ALTER PUBLICATION supabase_realtime ADD TABLE restaurants;
ALTER PUBLICATION supabase_realtime ADD TABLE vehicles;
ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE settings;

-- Insert default data
INSERT INTO restaurants (id, name, address, phone, email, lat, lng, rating, delivery_time, delivery_fee, cuisine, menu) VALUES
('damal-restaurant', 'Damal Restaurant', 'Downtown, Hargeisa', '+252 61 1234567', 'info@damal.com', 9.5600, 44.0650, 4.8, '25 min', '$2', 'Mediterranean', '{"coffee":[{"id":1,"name":"Espresso","price":3.50,"image":"https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=200&h=200&fit=crop","description":"Rich & bold single shot"},{"id":2,"name":"Cappuccino","price":4.25,"image":"https://images.unsplash.com/photo-1485808191679-5f86510681a2?w=200&h=200&fit=crop","description":"Espresso with steamed milk foam"}],"food":[{"id":4,"name":"Signature Burger","price":12.90,"image":"https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200&h=200&fit=crop","description":"Grilled beef, cheddar, fresh veggies"},{"id":5,"name":"Truffle Pasta","price":14.50,"image":"https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=200&h=200&fit=crop","description":"Creamy mushroom truffle sauce"}],"dessert":[{"id":7,"name":"New York Cheesecake","price":6.50,"image":"https://images.unsplash.com/photo-1533134242443-d4fd215305ad?w=200&h=200&fit=crop","description":"Creamy classic cheesecake"}]}'),
('hiddo-dhowr-pizza', 'Hiddo Dhowr Pizza', 'Main Street, Hargeisa', '+252 61 2345678', '', 9.5620, 44.0680, 4.9, '20 min', '$1.5', 'Italian', '{"coffee":[{"id":10,"name":"Italian Espresso","price":3.00,"image":"https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=200&h=200&fit=crop","description":"Authentic Italian roast"}],"food":[{"id":12,"name":"Margherita Pizza","price":10.50,"image":"https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=200&h=200&fit=crop","description":"Classic tomato, mozzarella, basil"},{"id":13,"name":"Pepperoni Pizza","price":12.90,"image":"https://images.unsplash.com/photo-1628840042765-356cda07504e?w=200&h=200&fit=crop","description":"Loaded with pepperoni"}],"dessert":[{"id":15,"name":"Tiramisu","price":7.25,"image":"https://images.unsplash.com/photo-1533134242443-d4fd215305ad?w=200&h=200&fit=crop","description":"Classic Italian dessert"}]}'),
('burger-house', 'Burger House', 'Central Market, Hargeisa', '+252 61 3456789', '', 9.5580, 44.0620, 4.7, '18 min', '$2', 'American', '{"coffee":[{"id":17,"name":"Americano","price":3.75,"image":"https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=200&h=200&fit=crop","description":"Espresso with hot water"}],"food":[{"id":18,"name":"Classic Burger","price":9.90,"image":"https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200&h=200&fit=crop","description":"Beef patty, lettuce, tomato"},{"id":19,"name":"Double Cheese Burger","price":13.50,"image":"https://images.unsplash.com/photo-1550547660-d9450f859349?w=200&h=200&fit=crop","description":"Double patty with extra cheese"}],"dessert":[{"id":21,"name":"Milkshake","price":5.50,"image":"https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=200&h=200&fit=crop","description":"Vanilla, chocolate, or strawberry"}]}'),
('som-coffee', 'Som Coffee', 'University Road, Hargeisa', '+252 61 4567890', '', 9.5640, 44.0700, 4.9, '15 min', '$1', 'Cafe', '{"coffee":[{"id":22,"name":"Somali Spiced Coffee","price":4.00,"image":"https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=200&h=200&fit=crop","description":"Traditional cardamom & clove"},{"id":23,"name":"Iced Latte","price":4.50,"image":"https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=200&h=200&fit=crop","description":"Cold espresso with milk"}],"food":[{"id":25,"name":"Croissant","price":3.25,"image":"https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=200&h=200&fit=crop","description":"Buttery French pastry"}],"dessert":[{"id":27,"name":"Baklava","price":4.50,"image":"https://images.unsplash.com/photo-1551103782-8ab07afd45c1?w=200&h=200&fit=crop","description":"Layers of filo with nuts & honey"}]}');

INSERT INTO vehicles (type, plate_number, driver_name, driver_phone, status, lat, lng) VALUES
('bike', 'B1234', 'Ahmed Ali', '+252631112222', 'available', 9.5650, 44.0700),
('taxi', 'T5678', 'Mohamed Hassan', '+252653334444', 'available', 9.5550, 44.0550),
('bike', 'B9012', 'Abdi Karim', '+252635556666', 'delivering', 9.5700, 44.0600),
('taxi', 'T2468', 'Fatima Omar', '+252657778888', 'available', 9.5610, 44.0660);

INSERT INTO settings (id, system) VALUES ('app', '{"businessName":"Go!Point","businessAddress":"Hargeisa, Somaliland","businessPhone":"+252 61 XXX XXXX","businessEmail":"info@gopoint.com"}');
