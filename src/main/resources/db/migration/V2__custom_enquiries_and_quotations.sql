SET search_path TO industrendindia,pg_catalog;

CREATE SEQUENCE IF NOT EXISTS custom_enquiry_code_seq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;
CREATE SEQUENCE IF NOT EXISTS custom_quotation_code_seq AS bigint START WITH 1 INCREMENT BY 1 NO CYCLE;

CREATE TABLE custom_enquiries (
  enquiry_id uuid PRIMARY KEY,
  enquiry_code varchar(7) NOT NULL DEFAULT ('E' || lpad(nextval('industrendindia.custom_enquiry_code_seq')::text, 6, '0')),
  customer_id uuid,
  store_id uuid NOT NULL,
  store_code varchar(7) NOT NULL CHECK (store_code ~ '^S[0-9]{6}$'),
  product_id uuid,
  product_code varchar(7) CHECK (product_code IS NULL OR product_code ~ '^P[0-9]{6}$'),
  product_name varchar(220) NOT NULL,
  customer_name varchar(160) NOT NULL,
  contact_phone_e164 varchar(16) NOT NULL,
  delivery_city varchar(120) NOT NULL,
  requested_size varchar(180),
  requested_finish varchar(180),
  requirements text NOT NULL,
  attachment_asset_id uuid,
  status varchar(28) NOT NULL DEFAULT 'RECEIVED' CHECK (status IN ('RECEIVED','CONTACTED','QUOTED','ACCEPTED','ORDERED','CANCELLED','EXPIRED')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT custom_enquiries_code_format_ck CHECK (enquiry_code ~ '^E[0-9]{6}$')
);
CREATE UNIQUE INDEX custom_enquiries_code_uq ON custom_enquiries(enquiry_code);
CREATE INDEX custom_enquiries_customer_created_idx ON custom_enquiries(customer_id,created_at DESC) WHERE customer_id IS NOT NULL;
CREATE INDEX custom_enquiries_store_status_idx ON custom_enquiries(store_id,status,created_at DESC);
CREATE INDEX custom_enquiries_phone_created_idx ON custom_enquiries(contact_phone_e164,created_at DESC);

CREATE TABLE custom_quotations (
  quotation_id uuid PRIMARY KEY,
  quotation_code varchar(7) NOT NULL DEFAULT ('Q' || lpad(nextval('industrendindia.custom_quotation_code_seq')::text, 6, '0')),
  enquiry_id uuid NOT NULL REFERENCES custom_enquiries(enquiry_id) ON DELETE RESTRICT,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  currency char(3) NOT NULL DEFAULT 'INR',
  estimated_completion varchar(180) NOT NULL,
  valid_until date NOT NULL,
  terms text NOT NULL,
  call_notes text,
  status varchar(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','SENT','ACCEPTED','EXPIRED','SUPERSEDED','CANCELLED')),
  created_by_admin_id uuid NOT NULL,
  sent_at timestamptz,
  accepted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE(enquiry_id,version),
  CONSTRAINT custom_quotations_code_format_ck CHECK (quotation_code ~ '^Q[0-9]{6}$')
);
CREATE UNIQUE INDEX custom_quotations_code_uq ON custom_quotations(quotation_code);
CREATE INDEX custom_quotations_enquiry_status_idx ON custom_quotations(enquiry_id,status,version DESC);
CREATE INDEX custom_quotations_payable_idx ON custom_quotations(valid_until,enquiry_id) WHERE status = 'SENT';

CREATE TABLE custom_enquiry_events (
  event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  enquiry_id uuid NOT NULL REFERENCES custom_enquiries(enquiry_id) ON DELETE CASCADE,
  actor_type varchar(20) NOT NULL CHECK (actor_type IN ('CUSTOMER','ADMIN','SYSTEM')),
  actor_id uuid,
  event_type varchar(80) NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX custom_enquiry_events_timeline_idx ON custom_enquiry_events(enquiry_id,created_at,event_id);

ALTER TABLE orders ADD COLUMN IF NOT EXISTS source_type varchar(20) NOT NULL DEFAULT 'CATALOGUE';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS quotation_id uuid;
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_source_type_ck;
ALTER TABLE orders ADD CONSTRAINT orders_source_type_ck CHECK (source_type IN ('CATALOGUE','CUSTOM_QUOTE'));
ALTER TABLE orders ADD CONSTRAINT orders_custom_quote_shape_ck CHECK (
  (source_type = 'CATALOGUE' AND quotation_id IS NULL) OR
  (source_type = 'CUSTOM_QUOTE' AND quotation_id IS NOT NULL)
);
CREATE UNIQUE INDEX orders_quotation_uq ON orders(quotation_id) WHERE quotation_id IS NOT NULL;

