-- Service Categories Table
CREATE TABLE IF NOT EXISTS seva_servicecategory (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Services Table
CREATE TABLE IF NOT EXISTS seva_service (
    id SERIAL PRIMARY KEY,
    provider_id INTEGER REFERENCES seva_auth_user(id),
    category_id INTEGER REFERENCES seva_servicecategory(id),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    duration_minutes INTEGER,
    location VARCHAR(255),
    status VARCHAR(20) DEFAULT 'active',
    image_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Bookings Table
CREATE TABLE IF NOT EXISTS seva_booking (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES seva_auth_user(id),
    service_id INTEGER REFERENCES seva_service(id),
    booking_date DATE,
    booking_time TIME,
    status VARCHAR(20) DEFAULT 'pending',
    notes TEXT,
    total_amount DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Reviews Table
CREATE TABLE IF NOT EXISTS seva_review (
    id SERIAL PRIMARY KEY,
    booking_id INTEGER REFERENCES seva_booking(id),
    customer_id INTEGER REFERENCES seva_auth_user(id),
    provider_id INTEGER REFERENCES seva_auth_user(id),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert some sample categories
INSERT INTO seva_servicecategory (name, description, icon) VALUES
('Cleaning', 'Home and office cleaning services', '🧹'),
('Plumbing', 'Plumbing and pipe repair services', '🔧'),
('Electrical', 'Electrical installation and repair', '⚡'),
('Beauty', 'Beauty and wellness services', '💅'),
('Tutoring', 'Educational and tutoring services', '📚'),
('Fitness', 'Personal training and fitness coaching', '💪'),
('Photography', 'Professional photography services', '📸'),
('Catering', 'Food and catering services', '🍽️');
