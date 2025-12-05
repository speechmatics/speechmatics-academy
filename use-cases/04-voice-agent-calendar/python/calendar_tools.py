"""
Google Calendar Tools for AI Receptionist
"""

import os
from datetime import datetime, timedelta
from typing import Optional
from zoneinfo import ZoneInfo

from livekit.agents import RunContext, function_tool
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build

# Configuration
TIMEZONE = os.getenv("TIMEZONE", "Europe/London")
CALENDAR_ID = os.getenv("GOOGLE_CALENDAR_ID", "primary")
APPOINTMENT_DURATION = int(os.getenv("APPOINTMENT_DURATION_MINUTES", "60"))

# Calendar service (lazy init)
_calendar_service = None


def get_calendar():
    """Get or create Google Calendar service."""
    global _calendar_service
    if _calendar_service is None:
        creds_file = os.getenv("GOOGLE_SERVICE_ACCOUNT_FILE", "credentials.json")
        if not os.path.exists(creds_file):
            return None
        creds = Credentials.from_service_account_file(
            creds_file, scopes=["https://www.googleapis.com/auth/calendar"]
        )
        _calendar_service = build("calendar", "v3", credentials=creds)
    return _calendar_service


def parse_date(date_str: str) -> datetime:
    """Parse ISO date from LLM, correcting past dates."""
    today = datetime.now(ZoneInfo(TIMEZONE))
    try:
        parsed = datetime.strptime(date_str, "%Y-%m-%d")
        if parsed.year < today.year:
            parsed = parsed.replace(year=today.year)
        if parsed.replace(tzinfo=ZoneInfo(TIMEZONE)).date() < today.date():
            parsed = parsed.replace(year=today.year + 1)
        return parsed
    except ValueError:
        return today


def parse_time(time_str: str) -> datetime:
    """Parse time string (e.g., '3:00 PM')."""
    time_str = time_str.lower().strip().replace(".", "").replace(" ", "")
    for fmt in ["%I:%M%p", "%I%p", "%H:%M"]:
        try:
            return datetime.strptime(time_str, fmt)
        except ValueError:
            continue
    return datetime.strptime("9:00am", "%I:%M%p")


def is_slot_available(calendar, start: datetime, end: datetime) -> bool:
    """Check if a time slot is available."""
    result = calendar.freebusy().query(body={
        "timeMin": start.isoformat(),
        "timeMax": end.isoformat(),
        "items": [{"id": CALENDAR_ID}]
    }).execute()
    return not result["calendars"][CALENDAR_ID]["busy"]


def find_customer_appointment(calendar, customer_name: str, date: Optional[str] = None):
    """Find appointment by customer name."""
    tz = ZoneInfo(TIMEZONE)
    now = datetime.now(tz)

    if date:
        target = parse_date(date)
        time_min = datetime(target.year, target.month, target.day, 0, 0, tzinfo=tz)
        time_max = time_min + timedelta(days=1)
    else:
        time_min = datetime(now.year, now.month, now.day, 0, 0, tzinfo=tz)
        time_max = time_min + timedelta(days=30)

    events = calendar.events().list(
        calendarId=CALENDAR_ID,
        timeMin=time_min.isoformat(),
        timeMax=time_max.isoformat(),
        q=customer_name,
        singleEvents=True,
        orderBy="startTime"
    ).execute().get("items", [])

    return events[0] if events else None


def fmt_time(dt: datetime) -> str:
    """Format time for speech (e.g., '3:00 PM')."""
    return dt.strftime("%I:%M %p").lstrip("0")


def fmt_date(dt: datetime) -> str:
    """Format date for speech (e.g., 'Tuesday, December 02')."""
    return dt.strftime("%A, %B %d")


def make_datetime(date: datetime, time: datetime) -> datetime:
    """Combine date and time into timezone-aware datetime."""
    return datetime(
        date.year, date.month, date.day,
        time.hour, time.minute, tzinfo=ZoneInfo(TIMEZONE)
    )


# ============================================================================
# Function Tools
# ============================================================================

@function_tool()
async def get_current_datetime(context: RunContext) -> str:
    """Get current date and time for scheduling appointments."""
    now = datetime.now(ZoneInfo(TIMEZONE))
    return f"Today is {now.strftime('%A, %B %d, %Y')}. Current year: {now.year}."


@function_tool()
async def check_availability(
    context: RunContext,
    date: str,
    time_of_day: Optional[str] = None,
    specific_time: Optional[str] = None,
) -> str:
    """
    Check available appointment slots.

    Args:
        date: Date to check (e.g., "2025-12-02")
        time_of_day: "morning", "afternoon", or "evening" for suggestions
        specific_time: Specific time to check (e.g., "3:00 PM")
    """
    calendar = get_calendar()
    if not calendar:
        return "Calendar not configured."

    try:
        target_date = parse_date(date)

        # Check specific time
        if specific_time:
            start = make_datetime(target_date, parse_time(specific_time))
            end = start + timedelta(minutes=APPOINTMENT_DURATION)

            if is_slot_available(calendar, start, end):
                return f"Yes, {fmt_time(start)} on {fmt_date(target_date)} is available!"
            return f"Sorry, {fmt_time(start)} is not available. Try another time?"

        # General availability - suggest 2-3 times
        hours = {"morning": (9, 12), "afternoon": (12, 17), "evening": (17, 19)}
        start_hour, end_hour = hours.get(time_of_day, (9, 19))

        tz = ZoneInfo(TIMEZONE)
        day_start = datetime(target_date.year, target_date.month, target_date.day, start_hour, 0, tzinfo=tz)
        day_end = datetime(target_date.year, target_date.month, target_date.day, end_hour, 0, tzinfo=tz)

        result = calendar.freebusy().query(body={
            "timeMin": day_start.isoformat(),
            "timeMax": day_end.isoformat(),
            "items": [{"id": CALENDAR_ID}]
        }).execute()

        busy_times = result["calendars"][CALENDAR_ID]["busy"]
        busy_periods = [
            (datetime.fromisoformat(b["start"].replace("Z", "+00:00")),
             datetime.fromisoformat(b["end"].replace("Z", "+00:00")))
            for b in busy_times
        ]

        # Find available slots
        slots = []
        current = day_start
        while current + timedelta(minutes=APPOINTMENT_DURATION) <= day_end:
            slot_end = current + timedelta(minutes=APPOINTMENT_DURATION)
            if all(slot_end <= bs or current >= be for bs, be in busy_periods):
                slots.append(current)
            current += timedelta(minutes=30)

        if not slots:
            return f"No slots on {fmt_date(target_date)}. Try another day?"

        # Suggest spread out times
        suggestions = [slots[0], slots[len(slots)//2], slots[-1]] if len(slots) >= 3 else slots
        times = ", ".join([fmt_time(s) for s in suggestions])
        return f"Available on {fmt_date(target_date)}: {times}. Which works?"

    except Exception as e:
        print(f"[ERROR] check_availability: {e}")
        return "Couldn't check calendar. Leave a message?"


@function_tool()
async def book_appointment(
    context: RunContext,
    date: str,
    time: str,
    customer_name: str,
    customer_phone: str,
    service_type: Optional[str] = None,
) -> str:
    """
    Book an appointment.

    Args:
        date: Appointment date
        time: Appointment time (e.g., "2:00 PM")
        customer_name: Customer's name
        customer_phone: Customer's phone
        service_type: Service requested
    """
    calendar = get_calendar()
    if not calendar:
        return "Calendar not configured."

    try:
        start = make_datetime(parse_date(date), parse_time(time))
        end = start + timedelta(minutes=APPOINTMENT_DURATION)

        if not is_slot_available(calendar, start, end):
            return "That slot was just taken. Try another time?"

        summary = f"{customer_name} - {service_type}" if service_type else customer_name
        description = f"Customer: {customer_name}\nPhone: {customer_phone}"
        if service_type:
            description += f"\nService: {service_type}"

        calendar.events().insert(calendarId=CALENDAR_ID, body={
            "summary": summary,
            "description": description,
            "start": {"dateTime": start.isoformat(), "timeZone": TIMEZONE},
            "end": {"dateTime": end.isoformat(), "timeZone": TIMEZONE},
        }).execute()

        return f"Booked! {fmt_date(start)} at {fmt_time(start)}. See you then, {customer_name}!"

    except Exception as e:
        print(f"[ERROR] book_appointment: {e}")
        return "Couldn't book. Try again?"


@function_tool()
async def cancel_appointment(
    context: RunContext,
    customer_name: str,
    date: Optional[str] = None,
) -> str:
    """
    Cancel an appointment.

    Args:
        customer_name: Name on the appointment
        date: Optional date to narrow search
    """
    calendar = get_calendar()
    if not calendar:
        return "Calendar not configured."

    try:
        event = find_customer_appointment(calendar, customer_name, date)
        if not event:
            return f"No appointment found for {customer_name}."

        calendar.events().delete(calendarId=CALENDAR_ID, eventId=event["id"]).execute()
        event_time = datetime.fromisoformat(event["start"]["dateTime"])
        return f"Cancelled: {fmt_date(event_time)} at {fmt_time(event_time)}."

    except Exception as e:
        print(f"[ERROR] cancel_appointment: {e}")
        return "Couldn't cancel. Leave a message?"


@function_tool()
async def reschedule_appointment(
    context: RunContext,
    customer_name: str,
    new_date: str,
    new_time: str,
    old_date: Optional[str] = None,
) -> str:
    """
    Reschedule an appointment.

    Args:
        customer_name: Name on the appointment
        new_date: New date
        new_time: New time
        old_date: Optional current date to find appointment
    """
    calendar = get_calendar()
    if not calendar:
        return "Calendar not configured."

    try:
        event = find_customer_appointment(calendar, customer_name, old_date)
        if not event:
            return f"No appointment found for {customer_name}. Book a new one?"

        new_start = make_datetime(parse_date(new_date), parse_time(new_time))
        new_end = new_start + timedelta(minutes=APPOINTMENT_DURATION)

        if not is_slot_available(calendar, new_start, new_end):
            return "That time isn't available. Try another?"

        event["start"] = {"dateTime": new_start.isoformat(), "timeZone": TIMEZONE}
        event["end"] = {"dateTime": new_end.isoformat(), "timeZone": TIMEZONE}
        calendar.events().update(calendarId=CALENDAR_ID, eventId=event["id"], body=event).execute()

        return f"Rescheduled to {fmt_date(new_start)} at {fmt_time(new_start)}!"

    except Exception as e:
        print(f"[ERROR] reschedule_appointment: {e}")
        return "Couldn't reschedule. Try again?"


# Export
CALENDAR_TOOLS = [
    get_current_datetime,
    check_availability,
    book_appointment,
    cancel_appointment,
    reschedule_appointment,
]
