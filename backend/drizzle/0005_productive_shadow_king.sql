CREATE TABLE IF NOT EXISTS "trial_reminders" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"merchant_slug" text,
	"label" text NOT NULL,
	"trial_ends_at" timestamp with time zone NOT NULL,
	"reminded_at" timestamp with time zone,
	"dismissed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "merchants" ADD COLUMN "trial_prone" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "subscriptions" ADD COLUMN "previous_amount" numeric(12, 2);--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "trial_reminders" ADD CONSTRAINT "trial_reminders_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
