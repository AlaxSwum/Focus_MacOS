-- =============================================
-- RULE BOOK DATABASE SCHEMA FOR SUPABASE
-- Run this SQL in your Supabase SQL Editor
-- =============================================

-- 1. Create rules table
CREATE TABLE IF NOT EXISTS rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    period TEXT NOT NULL CHECK (period IN ('daily', 'weekly', 'monthly', 'yearly')),
    target_count INTEGER NOT NULL DEFAULT 1,
    current_count INTEGER NOT NULL DEFAULT 0,
    streak_count INTEGER NOT NULL DEFAULT 0,
    best_streak INTEGER NOT NULL DEFAULT 0,
    total_completions INTEGER NOT NULL DEFAULT 0,
    total_points INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    emoji TEXT,
    color_hex TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_reset_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_completed_at TIMESTAMPTZ
);

-- 2. Create rule_checks table (history of each check)
CREATE TABLE IF NOT EXISTS rule_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID NOT NULL REFERENCES rules(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    points INTEGER NOT NULL DEFAULT 0
);

-- 3. Create user_rule_stats table (gamification stats)
CREATE TABLE IF NOT EXISTS user_rule_stats (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    total_points INTEGER NOT NULL DEFAULT 0,
    current_level INTEGER NOT NULL DEFAULT 0,
    total_rules_completed INTEGER NOT NULL DEFAULT 0,
    longest_streak INTEGER NOT NULL DEFAULT 0,
    current_day_streak INTEGER NOT NULL DEFAULT 0,
    badges TEXT[] DEFAULT '{}',
    last_active_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_rules_user_id ON rules(user_id);
CREATE INDEX IF NOT EXISTS idx_rules_period ON rules(period);
CREATE INDEX IF NOT EXISTS idx_rules_is_active ON rules(is_active);
CREATE INDEX IF NOT EXISTS idx_rule_checks_rule_id ON rule_checks(rule_id);
CREATE INDEX IF NOT EXISTS idx_rule_checks_user_id ON rule_checks(user_id);
CREATE INDEX IF NOT EXISTS idx_rule_checks_checked_at ON rule_checks(checked_at);

-- 5. Enable Row Level Security
ALTER TABLE rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE rule_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_rule_stats ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS Policies for rules table
CREATE POLICY "Users can view their own rules"
    ON rules FOR SELECT
    USING (auth.uid()::text = user_id::text OR user_id IN (
        SELECT id FROM users WHERE email = auth.email()
    ));

CREATE POLICY "Users can insert their own rules"
    ON rules FOR INSERT
    WITH CHECK (auth.uid()::text = user_id::text OR user_id IN (
        SELECT id FROM users WHERE email = auth.email()
    ));

CREATE POLICY "Users can update their own rules"
    ON rules FOR UPDATE
    USING (auth.uid()::text = user_id::text OR user_id IN (
        SELECT id FROM users WHERE email = auth.email()
    ));

CREATE POLICY "Users can delete their own rules"
    ON rules FOR DELETE
    USING (auth.uid()::text = user_id::text OR user_id IN (
        SELECT id FROM users WHERE email = auth.email()
    ));

-- 7. Create RLS Policies for rule_checks table
CREATE POLICY "Users can view their own rule checks"
    ON rule_checks FOR SELECT
    USING (auth.uid()::text = user_id::text OR user_id IN (
        SELECT id FROM users WHERE email = auth.email()
    ));

CREATE POLICY "Users can insert their own rule checks"
    ON rule_checks FOR INSERT
    WITH CHECK (auth.uid()::text = user_id::text OR user_id IN (
        SELECT id FROM users WHERE email = auth.email()
    ));

-- 8. Create RLS Policies for user_rule_stats table
CREATE POLICY "Users can view their own stats"
    ON user_rule_stats FOR SELECT
    USING (auth.uid()::text = user_id::text OR user_id IN (
        SELECT id FROM users WHERE email = auth.email()
    ));

CREATE POLICY "Users can insert their own stats"
    ON user_rule_stats FOR INSERT
    WITH CHECK (auth.uid()::text = user_id::text OR user_id IN (
        SELECT id FROM users WHERE email = auth.email()
    ));

CREATE POLICY "Users can update their own stats"
    ON user_rule_stats FOR UPDATE
    USING (auth.uid()::text = user_id::text OR user_id IN (
        SELECT id FROM users WHERE email = auth.email()
    ));

-- 9. Create function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 10. Create trigger for user_rule_stats updated_at
DROP TRIGGER IF EXISTS update_user_rule_stats_updated_at ON user_rule_stats;
CREATE TRIGGER update_user_rule_stats_updated_at
    BEFORE UPDATE ON user_rule_stats
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 11. Create function to initialize user stats when first rule is created
CREATE OR REPLACE FUNCTION initialize_user_stats()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_rule_stats (user_id)
    VALUES (NEW.user_id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 12. Create trigger to auto-create user stats
DROP TRIGGER IF EXISTS auto_create_user_stats ON rules;
CREATE TRIGGER auto_create_user_stats
    AFTER INSERT ON rules
    FOR EACH ROW
    EXECUTE FUNCTION initialize_user_stats();

-- =============================================
-- SAMPLE DATA (Optional - for testing)
-- =============================================

-- Uncomment below to add sample rules for user_id 1
/*
INSERT INTO rules (user_id, title, emoji, period, target_count, color_hex) VALUES
(1, 'No soda', '🚫', 'daily', 1, '#FF6B6B'),
(1, 'Drink 8 glasses of water', '💧', 'daily', 8, '#4ECDC4'),
(1, 'Go to gym', '💪', 'weekly', 4, '#45B7D1'),
(1, 'Read for 30 minutes', '📚', 'daily', 1, '#96CEB4'),
(1, 'Save $500', '💰', 'monthly', 1, '#FFEAA7'),
(1, 'No late sleep (before 11pm)', '😴', 'daily', 1, '#DDA0DD'),
(1, 'Meditate', '🧘', 'daily', 1, '#98D8C8'),
(1, 'Learn something new', '🎯', 'weekly', 3, '#F7DC6F');
*/

-- =============================================
-- VERIFICATION QUERIES
-- =============================================

-- Check tables were created
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('rules', 'rule_checks', 'user_rule_stats');

-- Check columns in rules table
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'rules';
