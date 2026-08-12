CREATE TYPE "public"."bank_link_status" AS ENUM('ACTIVE', 'REVOKED', 'ERROR');--> statement-breakpoint
CREATE TYPE "public"."billing_cycle" AS ENUM('WEEKLY', 'MONTHLY', 'QUARTERLY', 'YEARLY');--> statement-breakpoint
CREATE TYPE "public"."otp_purpose" AS ENUM('SIGNUP', 'RESET_PASSWORD');--> statement-breakpoint
CREATE TYPE "public"."subscription_category" AS ENUM('STREAMING', 'TELECOM', 'SOFTWARE', 'FITNESS', 'FINANCE', 'OTHER');--> statement-breakpoint
CREATE TYPE "public"."subscription_status" AS ENUM('UNREVIEWED', 'ACTIVE', 'CANCELLED');--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "charge_records" (
	"id" uuid PRIMARY KEY NOT NULL,
	"subscription_id" uuid NOT NULL,
	"date" timestamp with time zone NOT NULL,
	"amount" numeric(12, 2) NOT NULL,
	"narration" text NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "linked_banks" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"provider" text DEFAULT 'mono' NOT NULL,
	"bank_name" text NOT NULL,
	"bank_code" text NOT NULL,
	"account_number_mask" text NOT NULL,
	"provider_account_id" text NOT NULL,
	"provider_token" text NOT NULL,
	"status" "bank_link_status" DEFAULT 'ACTIVE' NOT NULL,
	"linked_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_synced_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "merchants" (
	"id" uuid PRIMARY KEY NOT NULL,
	"slug" text NOT NULL,
	"name" text NOT NULL,
	"domain" text NOT NULL,
	"brand_color" text NOT NULL,
	"category" "subscription_category" DEFAULT 'OTHER' NOT NULL,
	CONSTRAINT "merchants_slug_unique" UNIQUE("slug")
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "otp_codes" (
	"id" uuid PRIMARY KEY NOT NULL,
	"email" text NOT NULL,
	"code_hash" text NOT NULL,
	"purpose" "otp_purpose" NOT NULL,
	"attempts" integer DEFAULT 0 NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"consumed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"user_id" uuid
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "subscriptions" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"merchant_id" uuid,
	"display_name" text NOT NULL,
	"amount" numeric(12, 2) NOT NULL,
	"cycle" "billing_cycle" NOT NULL,
	"next_charge_date" timestamp with time zone NOT NULL,
	"category" "subscription_category" NOT NULL,
	"status" "subscription_status" DEFAULT 'UNREVIEWED' NOT NULL,
	"confidence" double precision DEFAULT 1 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "users" (
	"id" uuid PRIMARY KEY NOT NULL,
	"email" text NOT NULL,
	"password_hash" text,
	"email_verified_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "users_email_unique" UNIQUE("email")
);
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "charge_records" ADD CONSTRAINT "charge_records_subscription_id_subscriptions_id_fk" FOREIGN KEY ("subscription_id") REFERENCES "public"."subscriptions"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "linked_banks" ADD CONSTRAINT "linked_banks_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "otp_codes" ADD CONSTRAINT "otp_codes_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_merchant_id_merchants_id_fk" FOREIGN KEY ("merchant_id") REFERENCES "public"."merchants"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
