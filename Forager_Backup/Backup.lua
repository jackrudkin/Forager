-- Forager Backup: storage only. Forager writes ForagerBackupDB at logout and /reload
-- while its own data looks healthy, and restores from it if ForagerDB ever loads empty.
ForagerBackupDB = ForagerBackupDB or nil
