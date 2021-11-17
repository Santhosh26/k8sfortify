SET ANSI_NULLS, QUOTED_IDENTIFIER ON;
GO

UPDATE [dbo].[Scan] 
   SET [ScannerId]=NULL, 
       [ScanLogsBinaryFileId]=NULL, 
	   [ScanResultsBinaryFileId]=NULL, 
	   [SiteTreeBinaryFileId]=NULL, 
	   [FPRBinaryFileId]=NULL;
UPDATE [dbo].[Scanner] 
   SET [CurrentScanId]=NULL;
DELETE FROM [dbo].[PollingMessage];
DELETE FROM [dbo].[ScanEventLog];
DELETE FROM [dbo].[ScanBinaryFile];
DELETE FROM [dbo].[ScanBinaryFileUploadSession];
DELETE FROM [dbo].[Scan];
DELETE FROM [dbo].[Scanner];
GO