package com.nullx.pp;

import android.app.job.JobInfo;
import android.app.job.JobParameters;
import android.app.job.JobScheduler;
import android.app.job.JobService;
import android.content.ComponentName;
import android.content.Context;
import android.os.Build;

public class PersistentWorker extends JobService {
    private static final int JOB_ID = 1001;

    @Override
    public boolean onStartJob(JobParameters params) {
        // Keep service alive
        return false;
    }

    @Override
    public boolean onStopJob(JobParameters params) {
        return true;
    }

    public static void schedule(Context context) {
        JobScheduler scheduler = (JobScheduler) context.getSystemService(Context.JOB_SCHEDULER_SERVICE);
        if (scheduler != null) {
            ComponentName componentName = new ComponentName(context, PersistentWorker.class);
            JobInfo.Builder builder = new JobInfo.Builder(JOB_ID, componentName);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                builder.setMinimumLatency(60000);
                builder.setOverrideDeadline(120000);
                builder.setRequiresDeviceIdle(false);
            } else {
                builder.setPeriodic(60000);
            }
            scheduler.schedule(builder.build());
        }
    }
}