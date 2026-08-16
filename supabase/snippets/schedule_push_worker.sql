-- Run this in the Staging SQL Editor only after the push-worker Edge secrets
-- are configured. Replace the three placeholders before executing. Vault
-- encrypts the values; never put real credentials in a migration or Git.

select vault.create_secret(
    'https://PROJECT_REF.supabase.co',
    'wif_project_url',
    'Where Is My Friend Edge Function origin'
);

select vault.create_secret(
    'PUBLISHABLE_KEY',
    'wif_publishable_key',
    'Where Is My Friend public Edge gateway key'
);

select vault.create_secret(
    'PUSH_WORKER_SECRET',
    'wif_push_worker_secret',
    'Where Is My Friend cron-to-worker bearer secret'
);

select cron.unschedule(jobid)
from cron.job
where jobname = 'wif-push-worker-every-minute';

select cron.schedule(
    'wif-push-worker-every-minute',
    '* * * * *',
    $schedule$
    select net.http_post(
        url := (
            select decrypted_secret from vault.decrypted_secrets
            where name = 'wif_project_url'
        ) || '/functions/v1/push-worker',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'apikey', (
                select decrypted_secret from vault.decrypted_secrets
                where name = 'wif_publishable_key'
            ),
            'Authorization', 'Bearer ' || (
                select decrypted_secret from vault.decrypted_secrets
                where name = 'wif_push_worker_secret'
            )
        ),
        body := jsonb_build_object('scheduledAt', now())
    );
    $schedule$
);
