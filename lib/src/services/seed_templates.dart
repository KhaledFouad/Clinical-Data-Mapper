import '../models/domain.dart';

class SeedTemplates {
  static List<TargetTemplate> get all => [
    referringDoctors,
    usersAndDoctors,
    clinicsAndServices,
  ];

  static final referringDoctors = TargetTemplate(
    id: 'referring-doctors-sql',
    version: 1,
    name: 'Referring Doctors',
    description: 'Provisional 14-column order established by ImportReFListTemplate_Script.sql. Only code is an explicit source header.',
    verification: TemplateVerification.inferredFromSql,
    outputSheetName: 'ReferringDoctors',
    fields: const [
      TargetField(
        id: 'code',
        header: 'code',
        type: FieldType.identifier,
        required: true,
        description: 'Explicit SQL source column and provider match key.',
        aliases: ['code', 'code sih', 'رمز'],
      ),
      TargetField(
        id: 'full_name',
        header: 'FullName',
        type: FieldType.text,
        description: 'Full name; do not split automatically.',
        aliases: [
          'full name',
          'fullname',
          'nom complet',
          'prenom',
          'nom',
          'الاسم',
        ],
      ),
      TargetField(
        id: 'prefix',
        header: 'Prefix',
        type: FieldType.text,
        aliases: ['title', 'titre', 'prefix', 'اللقب'],
      ),
      TargetField(
        id: 'specialty',
        header: 'Specialty',
        type: FieldType.text,
        aliases: ['specialty', 'specialité', 'specialite', 'التخصص'],
      ),
      TargetField(
        id: 'address',
        header: 'Address',
        type: FieldType.text,
        aliases: ['address', 'adresse', 'العنوان'],
      ),
      TargetField(
        id: 'country',
        header: 'Country',
        type: FieldType.text,
        aliases: ['country', 'pays', 'الدولة'],
      ),
      TargetField(
        id: 'telephone',
        header: 'Telephone',
        type: FieldType.phone,
        aliases: ['telephone', 'téléphone', 'هاتف'],
      ),
      TargetField(
        id: 'fax',
        header: 'Fax',
        type: FieldType.phone,
        aliases: ['fax', 'telecopie', 'télécopie', 'فاكس'],
      ),
      TargetField(
        id: 'mobile',
        header: 'Mobile',
        type: FieldType.phone,
        aliases: ['mobile', 'portable', 'جوال'],
      ),
      TargetField(
        id: 'email',
        header: 'Email',
        type: FieldType.email,
        aliases: ['email', 'e-mail', 'courriel', 'البريد الإلكتروني'],
      ),
      TargetField(
        id: 'city',
        header: 'City',
        type: FieldType.text,
        aliases: ['city', 'ville', 'ville ou localité', 'المدينة'],
      ),
      TargetField(
        id: 'provider_type',
        header: 'ProviderType',
        type: FieldType.text,
        description: 'Secteur is only an unconfirmed candidate.',
        aliases: ['provider type', 'secteur', 'نوع مقدم الخدمة'],
      ),
      TargetField(
        id: 'postal_code',
        header: 'ZipCode',
        type: FieldType.identifier,
        aliases: [
          'zip',
          'zipcode',
          'postal code',
          'code postal',
          'الرمز البريدي',
        ],
      ),
      TargetField(
        id: 'state',
        header: 'State',
        type: FieldType.text,
        description: 'Region is only an unconfirmed candidate.',
        aliases: ['state', 'province', 'region', 'ولاية'],
      ),
    ],
    uniqueKeys: const [
      ['code'],
    ],
    businessRules: const [
      'SQL excludes rows whose code is NULL.',
      'Person.Comment and HealthcareProvider.ProviderCode are matched to code; existing records are reused without detail updates.',
      'Missing provider type becomes database ID 4 downstream; this ID is not exported as a textual value.',
      'Provider role ID 9 is assigned downstream.',
      'Missing names become Unknown in downstream person components.',
      "SQL NULL postal code becomes '0' downstream.",
      'Address and email are read but not inserted by the supplied SQL.',
      'Specialty creation remains, but provider-specialty and clinic-provider links are commented out.',
    ],
  );

  static final usersAndDoctors = TargetTemplate(
    id: 'users-doctors-sql',
    version: 1,
    name: 'Users and Doctors',
    description: 'Provisional three-column source expected by Create User&Emp&Person&Doctor_last_16092026.sql.',
    verification: TemplateVerification.inferredFromSql,
    outputSheetName: 'Users',
    fields: const [
      TargetField(
        id: 'full_name',
        header: 'UserCode',
        type: FieldType.text,
        required: true,
        description: 'Despite its name, the SQL treats UserCode as the person full name.',
        aliases: ['usercode', 'full name', 'name', 'nom', 'الاسم'],
      ),
      TargetField(
        id: 'username',
        header: 'ac',
        type: FieldType.identifier,
        required: true,
        description: 'Account username; downstream script generates an email.',
        aliases: ['ac', 'username', 'user name', 'login'],
      ),
      TargetField(
        id: 'department',
        header: 'Department',
        type: FieldType.text,
        description: 'DOC selects downstream provider role 8; other values select role 1.',
        aliases: ['department', 'dept', 'service', 'القسم'],
      ),
    ],
    uniqueKeys: const [
      ['username'],
    ],
    businessRules: const [
      'The downstream SQL creates or reuses employee, account, person and provider relationships.',
      'Email and account settings are generated downstream. Passwords are deliberately not exported.',
      'Name splitting in SQL is culturally fragile and remains a downstream behavior requiring confirmation.',
    ],
  );

  static final clinicsAndServices = TargetTemplate(
    id: 'clinics-services-sql',
    version: 1,
    name: 'Clinics and Services',
    description: 'Provisional five-column source expected by Create Clinic&Service&ClinicService&Price_Update.sql.',
    verification: TemplateVerification.inferredFromSql,
    outputSheetName: 'ServicePrice',
    fields: const [
      TargetField(
        id: 'clinic_name',
        header: 'ClinicName',
        type: FieldType.text,
        required: true,
        aliases: ['clinic name', 'clinic', 'عيادة'],
      ),
      TargetField(
        id: 'service_code',
        header: 'ServiceCode',
        type: FieldType.identifier,
        required: true,
        aliases: ['service code', 'servicecode', 'code service', 'رمز الخدمة'],
      ),
      TargetField(
        id: 'service_name_e',
        header: 'ServiceNameE',
        type: FieldType.text,
        required: true,
        description: 'Assigned to ItemNameA in SQL; suffix language meaning is unverified.',
        aliases: ['service name e', 'column1', 'english service name'],
      ),
      TargetField(
        id: 'service_name_f',
        header: 'ServiceNameF',
        type: FieldType.text,
        description: 'Assigned to ItemNameL in SQL; suffix language meaning is unverified.',
        aliases: [
          'service name f',
          'service name',
          'service name a',
          'arabic service name',
          'اسم الخدمة',
        ],
      ),
      TargetField(
        id: 'net_price',
        header: 'NetPrice',
        type: FieldType.decimal,
        required: true,
        aliases: ['net price', 'price', 'prix', 'السعر'],
      ),
    ],
    uniqueKeys: const [
      ['clinic_name', 'service_code'],
    ],
    businessRules: const [
      'Clinic matching uses name; service matching uses code.',
      'Duration 15 and price list 5 are hard-coded downstream.',
      'Existing prices are skipped; new prices receive additional-price rows.',
      'Care setting, category, branch and accounting identifiers are not consumed by this SQL.',
      'Rows that differ only in care setting or accounting may collapse downstream and must be reviewed.',
      'Candidate source-level key: service code + care setting, optionally extended by price list, branch or accounting fields.',
    ],
  );
}
