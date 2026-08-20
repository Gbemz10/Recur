CREATE TYPE "public"."category_source" AS ENUM('RULE', 'MONO', 'USER');--> statement-breakpoint
CREATE TYPE "public"."spending_category" AS ENUM('FOOD', 'TRANSPORT', 'BILLS', 'ENTERTAINMENT', 'HEALTH', 'SHOPPING', 'TRANSFERS', 'SAVINGS', 'LOANS', 'EDUCATION', 'OTHER');--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "budgets" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"category" "spending_category" NOT NULL,
	"monthly_limit" numeric(12, 2) NOT NULL,
	"notified_at_80" timestamp with time zone,
	"notified_at_100" timestamp with time zone,
	"notify_period" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "budgets_user_id_category_unique" UNIQUE("user_id","category")
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "user_category_rules" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"match_key" text NOT NULL,
	"category" "spending_category" NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "user_category_rules_user_id_match_key_unique" UNIQUE("user_id","match_key")
);
--> statement-breakpoint
ALTER TABLE "raw_transactions" ADD COLUMN "spend_category" "spending_category";--> statement-breakpoint
ALTER TABLE "raw_transactions" ADD COLUMN "category_source" "category_source";--> statement-breakpoint
ALTER TABLE "raw_transactions" ADD COLUMN "payee" text;--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "budgets" ADD CONSTRAINT "budgets_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "user_category_rules" ADD CONSTRAINT "user_category_rules_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
