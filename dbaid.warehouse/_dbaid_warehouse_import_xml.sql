/* Sample code to import data into tables from xml files.
   This is for the case where DBAid Collector is configured to email files to a central location.
   A full solution will include looping through multiple files in a folder, some sort of PowerShell script to extract attachments from items in a [shared] mailbox.
*/

/* XML schema for reference
<?xml version="1.0" standalone="yes"?>
<xs:schema id="DocumentElement" xmlns="" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:msdata="urn:schemas-microsoft-com:xml-msdata">
  <xs:element name="DocumentElement" msdata:IsDataSet="true" msdata:MainDataTable="get_agentjob_history" msdata:UseCurrentLocale="true">
    <xs:complexType>
      <xs:choice minOccurs="0" maxOccurs="unbounded">
        <xs:element name="get_agentjob_history">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="instance_guid" msdata:DataType="System.Guid, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" type="xs:string" minOccurs="0" />
              <xs:element name="run_datetime" msdata:DataType="System.DateTimeOffset" type="xs:anyType" minOccurs="0" />
              <xs:element name="job_name" type="xs:string" minOccurs="0" />
              <xs:element name="step_id" type="xs:int" minOccurs="0" />
              <xs:element name="step_name" type="xs:string" minOccurs="0" />
              <xs:element name="error_message" type="xs:string" minOccurs="0" />
              <xs:element name="run_status" type="xs:string" minOccurs="0" />
              <xs:element name="run_duration_sec" type="xs:int" minOccurs="0" />
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:choice>
    </xs:complexType>
  </xs:element>
</xs:schema>
*/

DECLARE @Doc xml,
        @hdoc int;

SET @Doc = (SELECT * FROM OPENROWSET(BULK '<path to xml file>\82C366FF-FAD9-4061-88BD-B3827EBFC978_get_agentjob_history_202011031408.xml', SINGLE_BLOB) AS x);

EXEC sp_xml_prepareDocument @hdoc OUTPUT, @Doc;

INSERT INTO [dbo].[warehouse_agentjob_history] ([instance_guid], [run_datetime], [job_name], [step_id], [step_name], [error_message], [run_status], [run_duration_sec])
  SELECT *
  FROM OPENXML(@hdoc, '//DocumentElement/get_agentjob_history')
  WITH (
    [instance_guid] uniqueidentifier 'instance_guid',
    [run_datetime] datetime2 'run_datetime',
    [job_name] sysname 'job_name',
    [step_id] int 'step_id',
    [step_name] sysname 'step_name',
    [error_message] nvarchar(2048) 'error_message',
    [run_status] varchar(17) 'run_status',
    [run_duration_sec] int 'run_duration_sec'
  );

EXEC sp_xml_removedocument @hdoc;
GO



/* XML schema for reference

<?xml version="1.0" standalone="yes"?>
<xs:schema id="DocumentElement" xmlns="" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:msdata="urn:schemas-microsoft-com:xml-msdata">
  <xs:element name="DocumentElement" msdata:IsDataSet="true" msdata:MainDataTable="get_backup_history" msdata:UseCurrentLocale="true">
    <xs:complexType>
      <xs:choice minOccurs="0" maxOccurs="unbounded">
        <xs:element name="get_backup_history">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="instance_guid" msdata:DataType="System.Guid, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" type="xs:string" minOccurs="0" />
              <xs:element name="database_name" type="xs:string" minOccurs="0" />
              <xs:element name="backup_type" type="xs:string" minOccurs="0" />
              <xs:element name="backup_start_date" msdata:DataType="System.DateTimeOffset" type="xs:anyType" minOccurs="0" />
              <xs:element name="backup_finish_date" msdata:DataType="System.DateTimeOffset" type="xs:anyType" minOccurs="0" />
              <xs:element name="is_copy_only" type="xs:boolean" minOccurs="0" />
              <xs:element name="software_name" type="xs:string" minOccurs="0" />
              <xs:element name="user_name" type="xs:string" minOccurs="0" />
              <xs:element name="physical_device_name" type="xs:string" minOccurs="0" />
              <xs:element name="backup_size_mb" type="xs:decimal" minOccurs="0" />
              <xs:element name="compressed_backup_size_mb" type="xs:decimal" minOccurs="0" />
              <xs:element name="compression_ratio" type="xs:decimal" minOccurs="0" />
              <xs:element name="backup_check_full_hour" type="xs:int" minOccurs="0" />
              <xs:element name="backup_check_diff_hour" type="xs:int" minOccurs="0" />
              <xs:element name="backup_check_tran_hour" type="xs:int" minOccurs="0" />
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:choice>
    </xs:complexType>
  </xs:element>
</xs:schema>

*/

DECLARE @Doc xml,
        @hdoc int;

SET @Doc = (SELECT * FROM OPENROWSET(BULK '<path to xml file>\82C366FF-FAD9-4061-88BD-B3827EBFC978_get_backup_history_202010291510.xml', SINGLE_BLOB) AS x);

EXEC sp_xml_prepareDocument @hdoc OUTPUT, @Doc;

INSERT INTO [dbo].[warehouse_backup_history] ([instance_guid], [database_name], [backup_type], [backup_start_date], [backup_finish_date], [is_copy_only], [software_name], [user_name], [physical_device_name], [backup_size_mb], [compressed_backup_size_mb], [compression_ratio], [backup_check_full_hour], [backup_check_diff_hour], [backup_check_tran_hour])
  SELECT *
  FROM OPENXML(@hdoc, '//DocumentElement/get_backup_history')
  WITH (
    [instance_guid] uniqueidentifier 'instance_guid',
    [database_name] sysname 'database_name',
    [backup_type] char(1) 'backup_type',
    [backup_start_date] datetime2 'backup_start_date',
    [backup_finish_date] datetime2 'backup_finish_date',
    [is_copy_only] bit 'is_copy_only',
    [software_name] sysname 'software_name',
    [user_name] sysname 'user_name',
    [physical_device_name] nvarchar(260) 'physical_device_name',
    [backup_size_mb] numeric(20,2) 'backup_size_mb',
    [compressed_backup_size_mb] numeric(20,2) 'compressed_backup_size_mb',
    [compression_ratio] numeric (20,2) 'compression_ratio',
    [backup_check_full_hour] int 'backup_check_full_hour',
    [backup_check_diff_hour] int 'backup_check_diff_hour',
    [backup_check_tran_hour] int 'backup_check_tran_hour'
  );

EXEC sp_xml_removedocument @hdoc;
GO




/* XML schema for reference 
<?xml version="1.0" standalone="yes"?>
<xs:schema id="DocumentElement" xmlns="" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:msdata="urn:schemas-microsoft-com:xml-msdata">
  <xs:element name="DocumentElement" msdata:IsDataSet="true" msdata:MainDataTable="get_capacity_db" msdata:UseCurrentLocale="true">
    <xs:complexType>
      <xs:choice minOccurs="0" maxOccurs="unbounded">
        <xs:element name="get_capacity_db">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="instance_guid" msdata:DataType="System.Guid, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" type="xs:string" minOccurs="0" />
              <xs:element name="datetimeoffset" msdata:DataType="System.DateTimeOffset" type="xs:anyType" minOccurs="0" />
              <xs:element name="database_name" type="xs:string" minOccurs="0" />
              <xs:element name="volume_mount_point" type="xs:string" minOccurs="0" />
              <xs:element name="data_type" type="xs:string" minOccurs="0" />
              <xs:element name="size_used_mb" type="xs:decimal" minOccurs="0" />
              <xs:element name="size_reserved_mb" type="xs:decimal" minOccurs="0" />
              <xs:element name="volume_available_mb" type="xs:decimal" minOccurs="0" />
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:choice>
    </xs:complexType>
  </xs:element>
</xs:schema>
*/

DECLARE @Doc xml,
        @hdoc int;

SET @Doc = (SELECT * FROM OPENROWSET(BULK '<path to xml file>\82C366FF-FAD9-4061-88BD-B3827EBFC978_get_capacity_db_202010291510.xml', SINGLE_BLOB) AS x);

EXEC sp_xml_prepareDocument @hdoc OUTPUT, @Doc;

INSERT INTO [dbo].[warehouse_capacity_db] ([instance_guid], [datetimeoffset], [database_name], [volume_mount_point], [data_type], [size_used_mb], [size_reserved_mb], [volume_available_mb])
  SELECT *
  FROM OPENXML(@hdoc, '//DocumentElement/get_capacity_db')
  WITH (
    [instance_guid] uniqueidentifier 'instance_guid',
    [datetimeoffset] datetime2 'datetimeoffset',
    [database_name] sysname 'database_name',
    [volume_mount_point] nvarchar(512) 'volume_mount_point',
    [data_type] varchar(4) 'data_type',
    [size_used_mb] numeric(20,2) 'size_used_mb',
    [size_reserved_mb] numeric(20,2) 'size_reserved_mb',
    [volume_available_mb] numeric(20,2) 'volume_available_mb'
  );

EXEC sp_xml_removedocument @hdoc;
GO




/* XML schema for reference 
<?xml version="1.0" standalone="yes"?>
<xs:schema id="DocumentElement" xmlns="" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:msdata="urn:schemas-microsoft-com:xml-msdata">
  <xs:element name="DocumentElement" msdata:IsDataSet="true" msdata:MainDataTable="get_database_ci" msdata:UseCurrentLocale="true">
    <xs:complexType>
      <xs:choice minOccurs="0" maxOccurs="unbounded">
        <xs:element name="get_database_ci">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="instance_guid" msdata:DataType="System.Guid, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" type="xs:string" minOccurs="0" />
              <xs:element name="datetimeoffset" msdata:DataType="System.DateTimeOffset" type="xs:anyType" minOccurs="0" />
              <xs:element name="name" type="xs:string" minOccurs="0" />
              <xs:element name="property" type="xs:string" minOccurs="0" />
              <xs:element name="value" msdata:DataType="System.Object, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" type="xs:anyType" minOccurs="0" />
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:choice>
    </xs:complexType>
  </xs:element>
</xs:schema>
*/

DECLARE @Doc xml,
        @hdoc int;

SET @Doc = (SELECT * FROM OPENROWSET(BULK '<path to xml file>\82C366FF-FAD9-4061-88BD-B3827EBFC978_get_database_ci_202010291510.xml', SINGLE_BLOB) AS x);

EXEC sp_xml_prepareDocument @hdoc OUTPUT, @Doc;

INSERT INTO [dbo].[warehouse_db] ([instance_guid], [datetimeoffset], [database_name], [property], [value])
  SELECT *
  FROM OPENXML(@hdoc, '//DocumentElement/get_database_ci')
  WITH (
    [instance_guid] uniqueidentifier 'instance_guid',
    [datetimeoffset] datetime2 'datetimeoffset',
    [database_name] sysname 'name',
    [property] sysname 'property',
    [value] sql_variant 'value'
  );

EXEC sp_xml_removedocument @hdoc;
GO




/* XML schema for reference 
<?xml version="1.0" standalone="yes"?>
<xs:schema id="DocumentElement" xmlns="" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:msdata="urn:schemas-microsoft-com:xml-msdata">
  <xs:element name="DocumentElement" msdata:IsDataSet="true" msdata:MainDataTable="get_instance_ci" msdata:UseCurrentLocale="true">
    <xs:complexType>
      <xs:choice minOccurs="0" maxOccurs="unbounded">
        <xs:element name="get_instance_ci">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="instance_guid" msdata:DataType="System.Guid, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" type="xs:string" minOccurs="0" />
              <xs:element name="datetimeoffset" msdata:DataType="System.DateTimeOffset" type="xs:anyType" minOccurs="0" />
              <xs:element name="property" type="xs:string" minOccurs="0" />
              <xs:element name="value" type="xs:string" minOccurs="0" />
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:choice>
    </xs:complexType>
  </xs:element>
</xs:schema>
*/

DECLARE @Doc xml,
        @hdoc int;

SET @Doc = (SELECT * FROM OPENROWSET(BULK '<path to xml file>\82C366FF-FAD9-4061-88BD-B3827EBFC978_get_instance_ci_202010291510.xml', SINGLE_BLOB) AS x);

EXEC sp_xml_prepareDocument @hdoc OUTPUT, @Doc;

INSERT INTO [dbo].[warehouse_instance] ([instance_guid], [datetimeoffset], [database_name], [property], [value])
  SELECT *
  FROM OPENXML(@hdoc, '//DocumentElement/get_instance_ci')
  WITH (
    [instance_guid] uniqueidentifier 'instance_guid',
    [datetimeoffset] datetime2 'datetimeoffset',
    [property] sysname 'property',
    [value] sql_variant 'value'
  );

EXEC sp_xml_removedocument @hdoc;
GO



/* XML schema for reference 
<?xml version="1.0" standalone="yes"?>
<xs:schema id="NewDataSet" xmlns="" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:msdata="urn:schemas-microsoft-com:xml-msdata">
  <xs:element name="NewDataSet" msdata:IsDataSet="true" msdata:MainDataTable="get_errorlog_history" msdata:UseCurrentLocale="true">
    <xs:complexType>
      <xs:choice minOccurs="0" maxOccurs="unbounded">
        <xs:element name="get_errorlog_history">
          <xs:complexType>
            <xs:sequence>
              <xs:element name="instance_guid" msdata:DataType="System.Guid, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" type="xs:string" minOccurs="0" />
              <xs:element name="log_date" msdata:DataType="System.DateTimeOffset" type="xs:anyType" minOccurs="0" />
              <xs:element name="source" type="xs:string" minOccurs="0" />
              <xs:element name="message_header" type="xs:string" minOccurs="0" />
              <xs:element name="message" type="xs:string" minOccurs="0" />
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:choice>
    </xs:complexType>
  </xs:element>
</xs:schema>
*/

DECLARE @Doc xml,
        @hdoc int;

SET @Doc = (SELECT * FROM OPENROWSET(BULK '<path to xml file>\82C366FF-FAD9-4061-88BD-B3827EBFC978_get_errorlog_history_202011031408.xml', SINGLE_BLOB) AS x);

EXEC sp_xml_prepareDocument @hdoc OUTPUT, @Doc;

INSERT INTO [dbo].[warehouse_errorlog] ([instance_guid], [log_date], [source], [message_header], [message])
  SELECT *
  FROM OPENXML(@hdoc, '//DocumentElement/get_errorlog_history')
  WITH (
    [instance_guid] uniqueidentifier 'instance_guid',
    [log_date] datetime2 'log_date',
    [source] nvarchar(100) 'source',
    [message_header] nvarchar(max) 'message_header',
    [message] nvarchar(max) 'message'
  );

EXEC sp_xml_removedocument @hdoc;
GO