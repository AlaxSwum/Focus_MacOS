-- =============================================
-- FOCUS APP - COMPLETE DATABASE SETUP
-- Run this SQL in your Supabase SQL Editor
-- =============================================

-- IMPORTANT: The Focus app uses "projects_meeting" table for meetings!
-- If you don't have this table, create it:

-- 1. ADD COMPLETED COLUMN TO PROJECTS_MEETING TABLE
-- This is the table the Focus app actually uses for meetings
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'projects_meeting' AND column_name = 'completed') THEN
        ALTER TABLE projects_meeting ADD COLUMN completed BOOLEAN DEFAULT false;
    END IF;
END $$;

-- 2. ADD COMPLETED COLUMN TO PERSONAL_TODOS TABLE
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'personal_todos' AND column_name = 'completed') THEN
        ALTER TABLE personal_todos ADD COLUMN completed BOOLEAN DEFAULT false;
    END IF;
END $$;

-- 3. ADD COMPLETED COLUMN TO TIME_BLOCKS TABLE
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'time_blocks' AND column_name = 'completed') THEN
        ALTER TABLE time_blocks ADD COLUMN completed BOOLEAN DEFAULT false;
    END IF;
END $$;

-- 4. CREATE FOCUS_SKIPPED_TASKS TABLE (if not exists)
CREATE TABLE IF NOT EXISTS focus_skipped_tasks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id INTEGER NOT NULL,
    task_id TEXT NOT NULL,
    task_type TEXT NOT NULL,
    task_title TEXT NOT NULL,
    task_date DATE NOT NULL,
    skip_reason TEXT,
    skipped_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. CREATE INDEXES FOR BETTER PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_projects_meeting_date ON projects_meeting(date);
CREATE INDEX IF NOT EXISTS idx_projects_meeting_completed ON projects_meeting(completed);
CREATE INDEX IF NOT EXISTS idx_personal_todos_user_id ON personal_todos(user_id);
CREATE INDEX IF NOT EXISTS idx_time_blocks_user_id ON time_blocks(user_id);
CREATE INDEX IF NOT EXISTS idx_time_blocks_date ON time_blocks(date);
CREATE INDEX IF NOT EXISTS idx_focus_skipped_tasks_user_id ON focus_skipped_tasks(user_id);

-- 6. ENABLE ROW LEVEL SECURITY
ALTER TABLE projects_meeting ENABLE ROW LEVEL SECURITY;
ALTER TABLE personal_todos ENABLE ROW LEVEL SECURITY;
ALTER TABLE time_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE focus_skipped_tasks ENABLE ROW LEVEL SECURITY;

-- 7. CREATE RLS POLICIES (allow all for now - customize as needed)
DROP POLICY IF EXISTS "Allow all on projects_meeting" ON projects_meeting;
CREATE POLICY "Allow all on projects_meeting" ON projects_meeting FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all on personal_todos" ON personal_todos;
CREATE POLICY "Allow all on personal_todos" ON personal_todos FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all on time_blocks" ON time_blocks;
CREATE POLICY "Allow all on time_blocks" ON time_blocks FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all on focus_skipped_tasks" ON focus_skipped_tasks;
CREATE POLICY "Allow all on focus_skipped_tasks" ON focus_skipped_tasks FOR ALL USING (true) WITH CHECK (true);

-- 8. VERIFY THE COMPLETED COLUMN EXISTS
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'projects_meeting' AND column_name = 'completed';

-- =============================================
-- HOW TO FIX "APP IS DAMAGED" ERROR ON NEW MAC
-- =============================================
-- 
-- Option 1: Right-click on Focus-macOS.app → "Open" → Click "Open"
-- Option 2: Run in Terminal: xattr -cr /Applications/Focus-macOS.app
-- Option 3: System Settings → Privacy & Security → "Open Anyway"
-- =============================================
