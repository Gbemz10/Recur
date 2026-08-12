CREATE TYPE "public"."transaction_type" AS ENUM('DEBIT', 'CREDIT');--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "raw_transactions" (
	"id" uuid PRIMARY KEY NOT NULL,
	"linked_bank_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"mono_transaction_id" text NOT NULL,
	"narration" text NOT NULL,
	"amount" numeric(12, 2) NOT NULL,
	"type" "transaction_type" NOT NULL,
	"category" text,
	"date" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "raw_transactions_linked_bank_id_mono_transaction_id_unique" UNIQUE("linked_bank_id","mono_transaction_id")
);
--> statement-breakpoint
ALTER TABLE "charge_records" ADD COLUMN "raw_transaction_id" uuid;--> statement-breakpoint
ALTER TABLE "subscriptions" ADD COLUMN "detection_key" text;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "raw_transactions" ADD CONSTRAINT "raw_transactions_linked_bank_id_linked_banks_id_fk" FOREIGN KEY ("linked_bank_id") REFERENCES "public"."linked_banks"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "raw_transactions" ADD CONSTRAINT "raw_transactions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "charge_records" ADD CONSTRAINT "charge_records_raw_transaction_id_raw_transactions_id_fk" FOREIGN KEY ("raw_transaction_id") REFERENCES "public"."raw_transactions"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
ALTER TABLE "charge_records" ADD CONSTRAINT "charge_records_raw_transaction_id_unique" UNIQUE("raw_transaction_id");--> statement-breakpoint
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_user_id_detection_key_unique" UNIQUE("user_id","detection_key");