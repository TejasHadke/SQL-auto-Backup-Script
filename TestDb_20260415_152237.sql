
-- =====================================
-- TABLE: Employee
-- =====================================
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE TABLE [dbo].[Employee](
	[EmployeeID] [int] IDENTITY(1,1) NOT NULL,
	[FirstName] [varchar](50) COLLATE Latin1_General_CI_AI NULL,
	[LastName] [varchar](50) COLLATE Latin1_General_CI_AI NULL,
	[Salary] [decimal](10, 2) NULL,
	[JoiningDate] [datetime] NULL
) ON [PRIMARY]

GO

-- =====================================
-- STORED PROCEDURE
-- =====================================
----EXEC sp_configure 'show advanced options', 1;
----RECONFIGURE;
----EXEC sp_configure 'xp_cmdshell', 1;
----RECONFIGURE;

CREATE PROCEDURE dbo.usp_SecureBackupCleanup
AS
BEGIN

    DECLARE @BackupPath NVARCHAR(255) = 'C:\TestBackups\';
    DECLARE @DatabaseName NVARCHAR(100) = 'TestDb';
    DECLARE @FileName NVARCHAR(255);
    
    -- Generate filename: MyDatabase_2026_01_09.bak
    SET @FileName = @BackupPath + @DatabaseName + '_' + FORMAT(GETDATE(), 'yyyy_MM_dd') + '.sql';
    
    BEGIN TRY
        -- 1. PERFORM THE BACKUP
        BACKUP DATABASE @DatabaseName 
        TO DISK = @FileName 
        --WITH FORMAT, INIT, SKIP, NOREWIND, NOUNLOAD, STATS = 100;
        WITH FORMAT, INIT, SKIP, NOREWIND, NOUNLOAD;

        -- 2. VERIFY TODAY'S FILE EXISTS (Safety Check)
        -- We use a temp table to store the results of a directory check

        CREATE TABLE #FileExists (FileExists INT);
        DECLARE @CheckCmd NVARCHAR(500) = 'if exist "' + @FileName + '" (echo 1) else (echo 0)';
        
        INSERT INTO #FileExists EXEC xp_cmdshell @CheckCmd;
        
        IF EXISTS (SELECT 1 FROM #FileExists WHERE FileExists = 1)
        BEGIN
            PRINT 'Success: Today''s backup verified. Proceeding to delete files older than 7 days...';

            -- 3. DELETE OLD FILES (The pure CMD way)
            -- /p is path, /s is subfolders, /d -7 is older than 7 days, /c is the command to run
            DECLARE @DeleteCmd NVARCHAR(500);
            
            SET @DeleteCmd = 'forfiles /p ' + @BackupPath + ' /m *.sql /d -7 /c "cmd /c del 0x22@path0x22"';
            
            EXEC xp_cmdshell @DeleteCmd, NO_OUTPUT;
        END
        ELSE
        BEGIN
            RAISERROR('Backup file was not created successfully. Cleanup aborted!', 16, 1);
        END

        DROP TABLE #FileExists;

    END TRY
    BEGIN CATCH
        SELECT ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END
GO

-- =====================================
-- FUNCTION
-- =====================================
CREATE FUNCTION dbo.fn_GetAnnualSalary
(
    @MonthlySalary DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN (@MonthlySalary * 12);
END;
GO

