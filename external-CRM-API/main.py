
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import json
import sqlite3

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(
    title="Project 02 - External CRM API",
    version="1.0.0"
)

databasePath = Path(__file__).with_name("crm.db")


class ContactInput(BaseModel):
    firstName: str = Field(min_length=1)
    lastName: str = Field(min_length=1)
    email: str = Field(min_length=3)
    phone: str = ""
    company: str = ""
    service: str = ""
    budget: Optional[float] = Field(default=None, ge=0)
    message: str = ""


class ContactUpdate(BaseModel):
    firstName: Optional[str] = None
    lastName: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    company: Optional[str] = None
    service: Optional[str] = None
    budget: Optional[float] = Field(default=None, ge=0)
    message: Optional[str] = None


def getConnection():
    connection = sqlite3.connect(
        databasePath,
        timeout=10
    )
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA busy_timeout = 10000")
    return connection


def initializeDatabase():
    with closing(getConnection()) as connection:
        connection.execute("""
            CREATE TABLE IF NOT EXISTS contacts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                firstName TEXT NOT NULL,
                lastName TEXT NOT NULL,
                email TEXT NOT NULL UNIQUE,
                phone TEXT NOT NULL DEFAULT '',
                company TEXT NOT NULL DEFAULT '',
                service TEXT NOT NULL DEFAULT '',
                budget REAL,
                message TEXT NOT NULL DEFAULT '',
                version INTEGER NOT NULL DEFAULT 1,
                updatedAt TEXT NOT NULL
            )
        """)

        connection.execute("""
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                contactId INTEGER NOT NULL,
                eventType TEXT NOT NULL,
                payload TEXT NOT NULL,
                createdAt TEXT NOT NULL
            )
        """)

        connection.commit()


def getTimestamp():
    return datetime.now(timezone.utc).isoformat()


def normalizeEmail(email):
    normalized = email.strip().lower()

    if (
        "@" not in normalized
        or "." not in normalized.split("@")[-1]
        or " " in normalized
    ):
        raise HTTPException(
            status_code=422,
            detail="Invalid email address"
        )

    return normalized


def recordEvent(connection, contact, eventType):
    timestamp = getTimestamp()

    connection.execute(
        """
        INSERT INTO events
        (contactId, eventType, payload, createdAt)
        VALUES (?, ?, ?, ?)
        """,
        (
            contact["id"],
            eventType,
            json.dumps(dict(contact)),
            timestamp
        )
    )


initializeDatabase()


@app.get("/health")
def checkHealth():
    return {
        "status": "healthy",
        "service": "externalCrmApi"
    }


@app.post("/contacts", status_code=201)
def createContact(data: ContactInput):
    values = data.model_dump()
    values["email"] = normalizeEmail(values["email"])
    timestamp = getTimestamp()

    with closing(getConnection()) as connection:
        try:
            connection.execute("BEGIN IMMEDIATE")

            cursor = connection.execute(
                """
                INSERT INTO contacts
                (
                    firstName, lastName, email,
                    phone, company, service,
                    budget, message, updatedAt
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    values["firstName"],
                    values["lastName"],
                    values["email"],
                    values["phone"],
                    values["company"],
                    values["service"],
                    values["budget"],
                    values["message"],
                    timestamp
                )
            )

            contactId = cursor.lastrowid

            contact = connection.execute(
                "SELECT * FROM contacts WHERE id = ?",
                (contactId,)
            ).fetchone()

            recordEvent(connection, contact, "created")
            connection.commit()

            return dict(contact)

        except sqlite3.IntegrityError:
            connection.rollback()
            raise HTTPException(
                status_code=409,
                detail="Contact email already exists"
            )


@app.get("/contacts")
def getContacts():
    with closing(getConnection()) as connection:
        rows = connection.execute(
            "SELECT * FROM contacts ORDER BY id"
        ).fetchall()

        return [dict(row) for row in rows]


@app.get("/contacts/{contactId}")
def getContact(contactId: int):
    with closing(getConnection()) as connection:
        contact = connection.execute(
            "SELECT * FROM contacts WHERE id = ?",
            (contactId,)
        ).fetchone()

        if contact is None:
            raise HTTPException(
                status_code=404,
                detail="Contact not found"
            )

        return dict(contact)


@app.patch("/contacts/{contactId}")
def updateContact(
    contactId: int,
    data: ContactUpdate
):
    changes = data.model_dump(exclude_unset=True)

    if not changes:
        raise HTTPException(
            status_code=400,
            detail="No fields provided"
        )

    for field in ("firstName", "lastName", "email"):
        if field in changes:
            if not isinstance(changes[field], str):
                raise HTTPException(
                    status_code=422,
                    detail=f"{field} cannot be null"
                )
            if not changes[field].strip():
                raise HTTPException(
                    status_code=422,
                    detail=f"{field} cannot be empty"
                )
            changes[field] = changes[field].strip()

    if "email" in changes:
        changes["email"] = normalizeEmail(
            changes["email"]
        )

    for field in (
        "phone", "company", "service", "message"
    ):
        if field in changes and changes[field] is None:
            changes[field] = ""

    with closing(getConnection()) as connection:
        connection.execute("BEGIN IMMEDIATE")

        current = connection.execute(
            "SELECT * FROM contacts WHERE id = ?",
            (contactId,)
        ).fetchone()

        if current is None:
            connection.rollback()
            raise HTTPException(
                status_code=404,
                detail="Contact not found"
            )

        updated = dict(current)
        updated.update(changes)

        updated["version"] += 1
        updated["updatedAt"] = getTimestamp()

        try:
            connection.execute(
                """
                UPDATE contacts SET
                    firstName = ?,
                    lastName = ?,
                    email = ?,
                    phone = ?,
                    company = ?,
                    service = ?,
                    budget = ?,
                    message = ?,
                    version = ?,
                    updatedAt = ?
                WHERE id = ?
                """,
                (
                    updated["firstName"],
                    updated["lastName"],
                    updated["email"],
                    updated["phone"],
                    updated["company"],
                    updated["service"],
                    updated["budget"],
                    updated["message"],
                    updated["version"],
                    updated["updatedAt"],
                    contactId
                )
            )

            contact = connection.execute(
                "SELECT * FROM contacts WHERE id = ?",
                (contactId,)
            ).fetchone()

            recordEvent(
                connection,
                contact,
                "updated"
            )

            connection.commit()

            return dict(contact)

        except sqlite3.IntegrityError:
            connection.rollback()
            raise HTTPException(
                status_code=409,
                detail="Email already belongs to another contact"
            )


@app.get("/events")
def getEvents(
    afterId: int = 0,
    limit: int = 100
):
    if afterId < 0 or not 1 <= limit <= 100:
        raise HTTPException(
            status_code=422,
            detail="Invalid pagination parameters"
        )

    with closing(getConnection()) as connection:
        rows = connection.execute(
            """
            SELECT * FROM events
            WHERE id > ?
            ORDER BY id ASC
            LIMIT ?
            """,
            (afterId, limit)
        ).fetchall()

        return [
            {
                "eventId": row["id"],
                "contactId": row["contactId"],
                "eventType": row["eventType"],
                "contact": json.loads(row["payload"]),
                "createdAt": row["createdAt"]
            }
            for row in rows
        ]
