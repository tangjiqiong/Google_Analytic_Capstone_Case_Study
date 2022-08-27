## how consumers use the smart device, impact the marketing strategy like push more notifications on morning, weekdays; ads on improvements of health quality like sleep and heartrate

## the frequency consumers use the device: which dates/hours/minutes do they take most steps
## if the product help people sleep for a lasting longer time or earlier at night
## if the product could help people do more instentive runnings

# The tables I'm gonna use are dailyavtivity, heartrate_seconds_merged, sleepDay_merged, weightLogInfo_merged and 
# hourlyactivity (merge hourlySteps_merged, hourlyIntensities_merged, hourlyCalories_merged)

# Merge tables and also adjust the datetime type
create table hourlyActivity_merged as
select *, case 
	when hour = '12:00:00 AM' then (substring_index(hour, ':', 1) - 12) 
	when hour like '%AM' then substring_index(hour, ':', 1) 
	when hour = '12:00:00 PM' then substring_index(hour, ':', 1)
	else (substring_index(hour, ':', 1) + 12) end as hour_24
from (
select *, concat(right(activitydate,4),'-',lpad(substring_index(activitydate, '/',1),2,'0'),'-',lpad(substring_index(substring_index(activitydate, '/',2),'/',-1),2,'0')) date
from (
select s.id, STR_TO_DATE(s.activityhour, '%c/%e/%Y %r') time, SUBSTRING_INDEX(s.activityHour, ' ', 1) as activitydate, SUBSTRING_INDEX(s.activityHour, ' ', -2) as hour, s.steptotal, c.calories, i.totalintensity, i.averageintensity 
from hourlySteps_merged s left join hourlyCalories_merged c on s.id = c.id and s.activityhour = c.activityhour
left join hourlyIntensities_merged i on s.id = i.id and s.activityhour = i.activityhour
) t
) sub;

select *
from hourlyactivity_merged

#first, we get the total number of users and total number of tracking days
select count(distinct id) as num_users, count(distinct ActivityDate) as num_days
from dailyActivity_merged;

# a quick look at weight info, which has many missing values and only has 8 participants
select logid, count(*)
from weightLogInfo_merged
group by logid;

# average BMI of these 8 participants is 27.872499942779537 which represents 'overweight'
# change of BMI, do participants become healthier
select *, end_bmi - start_bmi bmi_change, case when start_bmi >= 25 then 'overweighted' else 'normal' end as body_atart_status, case when end_bmi >= 25 then 'overweighted' else 'normal' end as body_end_status
from (
select distinct id, first_value(BMI) over (partition by id) start_bmi, LAST_VALUE(BMI) over (partition by id) end_bmi
from weightLogInfo_merged) sub;


# in terms of numeric features, we could analyze their maximums, means or some statistical numbers and could calculate the frequency or trend of each person on each day 
select activitydate, avg(totalsteps) avg_steps
from dailyActivity_merged
group by activitydate;

# start with the daily DATA

# wrong commands
-- select distinct id, activitydate, totalsteps
-- from dailyActivity_merged da 
-- where totalsteps in (select max(totalsteps) over (partition by id) m from dailyActivity_merged)

# right commands
-- select distinct da.id, activitydate, totalsteps as max_steps
-- from dailyActivity_merged da join (select id, max(totalsteps) over (partition by id) m from dailyActivity_merged) sub on da.id = sub.id
-- where totalsteps = m
-- order by id;

select *
from (
select distinct id, activitydate, case when totalsteps = max(totalsteps) over (partition by id) then totalsteps else null end as max_step, case when totalsteps = min(totalsteps) over (partition by id) then totalsteps else null end as min_step
from dailyActivity_merged
where totalsteps <> 0) sub
where max_step is not null or min_step is not null
order by id;


# daily steps level
with temp as (
select id, count(*) total_usedays, count(*) - sum(zerostep) nonzerostep_days, avg(totalsteps) avg_steps, max(totalsteps) max_steps, min(totalsteps) min_steps, avg(calories) avg_dailycal
from (select *, if(totalsteps = 0,1,0) as zerostep from dailyActivity_merged) sub
group by id),

daily_avg_steps as (
select *, nonzerostep_days/total_usedays nonzero_rate, 
case when avg_steps >= 10000 then '>=10000' when avg_steps >= 7000 then '7000-10000' when avg_steps >= 5000 then '5000-7000' when avg_steps >= 3000 then '3000-5000' when avg_steps >= 1000 then '1000-3000' else '<1000' end as avgsteps_level,
case when avg_dailycal >= 2000 then '>=2000' when avg_steps >= 1500 then '1500-2000' when avg_steps >= 1000 then '1000-1500' else '<1000' end as caloriesburned_level
from temp),

workout_level as (
select workout_level, count(*) cnt
from (
select *, case when nonzero_rate = 1 then 'walk every day' when nonzero_rate >0.9 then 'walk 90% days' when nonzero_rate >0.8 then 'walk 80% days' when nonzero_rate >0.7 then 'walk 70% days' else 'seldom walk ' end as workout_level
-- distinct avgsteps_level, count(*) over (partition by avgsteps_level)/33 freq
from daily_avg_steps) sub
group by workout_level)

select *
from daily_avg_steps
;


# steps, active_rate & calories
select id, avg(veryactive_rate), avg(fairlyactive_rate), avg(lightlyactive_rate), avg(active_rate), avg(sedentary_rate), avg(calories) avg_calories
from (
select id, activitydate, veryactiveminutes/1440 veryactive_rate, fairlyactiveminutes/1440 fairlyactive_rate, lightlyactiveminutes/1440 lightlyactive_rate, sedentaryminutes/1440 sedentary_rate, calories, (veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes)/1440 as active_rate
from dailyActivity_merged) sub
group by id
order by avg_calories desc;


select id, avg(averageintensity) avg_intensity, avg(calories) avg_calories
from hourlyactivity_merged
group by id


# go to the hourly DATA, divide into 3 parts

with hourly_maxmin_steps as (
select *
from (
select distinct id, activitydate, hour, case when steptotal = max(steptotal) over (partition by id, activitydate) then steptotal else null end as max_step, case when steptotal = min(steptotal) over (partition by id, activitydate) then steptotal else null end as min_step
from hourlyActivity_merged
where steptotal <> 0) sub
where max_step is not null or min_step is not null
order by id)

select * 
from hourly_maxmin_steps;


select id, hour, avg(steptotal) avg_steptotal
from hourlyactivity_merged
group by id, hour;


select id, hour_range, avg(steptotal)
from (select id, activitydate, hour, case when hour_24 > 6 and hour_24 <= 12 then 'morning' when hour_24 > 12 and hour_24 <= 18 then 'afternoon' else 'evening' end as hour_range, steptotal, calories, totalintensity, averageintensity
from hourlyactivity_merged) sub
group by id, hour_range;

select hour_range, avg(steptotal)
from (select id, activitydate, hour, case when hour_24 > 6 and hour_24 <= 12 then 'morning' when hour_24 > 12 and hour_24 <= 18 then 'afternoon' else 'evening' end as hour_range, steptotal, calories, totalintensity, averageintensity
from hourlyactivity_merged) sub
group by hour_range;



# daily data considering the weekdays or weekends

with weekly as (
select id, activitydate, case when weekday(cast(concat(year,'-',month,'-',day) as date)) <= 4 then 'weekdays' else 'weekend' end as weekday, totalsteps, calories
from (select *, lpad(substring_index(activitydate, '/',1),2,'0') month, lpad(substring_index(substring_index(activitydate, '/',2),'/',-1),2,'0') day, right(activitydate,4) year
from dailyActivity_merged) sub),

avg_de as (
select id, sum(wds_avg) weekdays_avg, sum(wes_avg) weekends_avg
from (
select id, case when weekday = 'weekdays' then ifnull(avg(totalsteps),0) end as wds_avg, case when weekday = 'weekend' then ifnull(avg(totalsteps),0) end as wes_avg
from weekly
group by id, weekday
) sub
group by id)

select distinct weekdays_level
-- , count(*) over (partition by weekdays_level) cnt_level_weekdays
, count(*) over (partition by weekdays_level) cnt_level_weekdays
from (
select *, case when weekdays_avg >= 10000 then '>=10000' when weekdays_avg >= 7000 then '7000-10000' when weekdays_avg >= 5000 then '5000-7000' when weekdays_avg >= 3000 then '3000-5000' when weekdays_avg >= 1000 then '1000-3000' else '<1000' end as weekdays_level, 
case when weekends_avg >= 10000 then '>=10000' when weekends_avg >= 7000 then '7000-10000' when weekends_avg >= 5000 then '5000-7000' when weekends_avg >= 3000 then '3000-5000' when weekends_avg >= 1000 then '1000-3000' else '<1000' end as weekends_level
from avg_de) t;



# about the activetime + sedentarytime, sleeptime

with daily_active_sleep as 
(select id, activitydate, (veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes)/(veryactiveminutes + fairlyactiveminutes + lightlyactiveminutes + sedentaryminutes) active_rate,
totalminutesasleep,totalminutesasleep/1440 sleep_rate, sum(if(totalminutesasleep is not null, 1, 0)) over (partition by id) as totalsleepdays, totalsleeprecords
from (
select da.id, activitydate, veryactiveminutes, fairlyactiveminutes, lightlyactiveminutes, sedentaryminutes, totalsleeprecords, totalminutesasleep, totaltimeinbed
from dailyActivity_merged da left join 
(select id, trim(right(sleepday, 12) from sleepday) date, totalsleeprecords, totalminutesasleep, totaltimeinbed
from sleepDay_merged) sub on da.id = sub.id and da.activitydate = sub.date) sub
)

select id, avg(active_rate) daily_avg_active_rate, avg(totalminutesasleep) avg_sleepminutes, avg(sleep_rate) avg_sleep_rate, avg(totalsleeprecords) avg_sleeprecords
from daily_active_sleep
group by id;






# also, sleep efficiency (sleep_over_inbed)

select id, substring_index(sleepday,' ', 1) sleepdate, totalminutesasleep, totaltimeinbed, totalminutesasleep/totaltimeinbed as sleep_over_inbed_rate
from sleepDay_merged;


with se as (select distinct id, first_value(se) over (partition by id) start_se, last_value(se) over (partition by id) end_se
from (
select *, totalminutesasleep / totaltimeinbed se
from sleepDay_merged) sub)

select *, end_se - start_se se_change
-- avg(start_se), avg(end_se)
from se



## sleep quality: when sleep and wake up, there are asleep at night or nap in the afternoon 
# outliers: do something but leave the app behind for 0 records or have a very unhealthy live

with cte as (
select id, time, date, steptotal, cast(hour_24 as UNSIGNED) hour_24
from hourlyactivity_merged
order by id, date, hour_24),

cte1 as (
select h1.id, h1.time, h1.steptotal, h2.time for_hour, h2.steptotal for_step
from cte h1 left join cte h2 on h1.id = h2.id and DATE_ADD(h1.time,INTERVAL 1 hour) = h2.time),

sleep_points as (select id, time sleeppoint, row_number() over (partition by id order by time) sleep_th, first_value(time) over (partition by id) first_sleeppoint from cte1 where for_step = 0 and steptotal <> 0),
wake_points as (select id, time wakepoint, row_number() over (partition by id order by time) wake_th, first_value(time) over (partition by id) first_wakepoint from cte1 where for_step <> 0 and steptotal = 0),

sleep_wake as (
select *, cast(substring_index(timediff(wakepoint, sleeppoint),':',1) as unsigned) break_hours
from (
select sleep_points.id, sleeppoint, wakepoint
from sleep_points join wake_points
on sleep_points.id = wake_points.id and sleep_points.sleep_th = wake_points.wake_th and first_sleeppoint < first_wakepoint
UNION
select sleep_points.id, sleeppoint, wakepoint 
from sleep_points join wake_points
on sleep_points.id = wake_points.id and sleep_points.sleep_th = wake_points.wake_th - 1 and first_sleeppoint > first_wakepoint) when_sleep_wake),

nap as (
select t.id, t.date, ifnull(avg_naphours,0) avg_hours, case when avg_naphours <= 1 then 'disco naps' when avg_naphours <= 1.5 then 'cycle naps' when avg_naphours <= 2 then 'groggy naps' when avg_naphours > 2 then 'sleep deprivation' else 'no nap' end as nap_indicator
from (
select id, date(sleeppoint) date, ifnull(avg(break_hours),0) avg_naphours
from sleep_wake
where date(sleeppoint) = date(wakepoint)
group by id, date(sleeppoint)) sub right join (select distinct id, date from hourlyactivity_merged) t on sub.date = t.date and sub.id = t.id ),

wake_freq as (
select wake_hourpoint, sum(freq) total_times
-- id, sleep_hourpoint, max_freq
from (
select id, wake_hourpoint, count(*) freq, max(count(*)) over (partition by id) max_freq
from (
select id, time(sleeppoint) sleep_hourpoint, time(wakepoint) wake_hourpoint
from sleep_wake)sub
group by id, wake_hourpoint) t
-- where freq = max_freq;
group by wake_hourpoint),

sleep_freq as (
select sleep_hourpoint, sum(freq) total_times
-- id, sleep_hourpoint, max_freq
from (
select id, sleep_hourpoint, count(*) freq, max(count(*)) over (partition by id) max_freq
from (
select id, time(sleeppoint) sleep_hourpoint, time(wakepoint) wake_hourpoint
from sleep_wake)sub
group by id, sleep_hourpoint) t
-- where freq = max_freq;
group by sleep_hourpoint)

select *
from nap

select sleep_freq.sleep_hourpoint hourpoint, sleep_freq.total_times total_sleep_times, wake_freq.total_times total_wake_times
from sleep_freq join wake_freq on sleep_freq.sleep_hourpoint = wake_freq.wake_hourpoint
order by hourpoint;

select date, nap_indicator, count(*) cnt
from nap
group by date, nap_indicator
order by date;

select date, sum(if(nap_indicator = 'no nap',1,0)) as cnt_no_naps, sum(if(nap_indicator = 'disco naps',1,0)) as cnt_disco_naps, sum(if(nap_indicator = 'cycle naps',1,0)) as cnt_cycle_naps, sum(if(nap_indicator = 'groggy naps',1,0)) as cnt_groggy_naps, sum(if(nap_indicator = 'sleep deprivation',1,0)) as cnt_sleep_deprivation
from nap
group by date






