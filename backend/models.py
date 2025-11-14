from sqlalchemy import Column, String, Text, Numeric, Integer, ForeignKey, DateTime
from sqlalchemy.dialects.postgresql import JSONB, ARRAY
from sqlalchemy.orm import relationship
from datetime import datetime
from .db import Base

class Place(Base):
    __tablename__ = 'places'

    id = Column(String, primary_key=True)  # expect '21...' ids
    name = Column(Text, nullable=False)
    category = Column(Text, nullable=False)
    subcategory = Column(Text)
    description = Column(Text)
    history = Column(Text)
    nearby_recommendations = Column(JSONB)  # list of strings/objects
    personal_tips = Column(Text)
    lat = Column(Numeric(9, 6), nullable=False)
    lng = Column(Numeric(9, 6), nullable=False)
    opening_hours = Column(JSONB)
    price = Column(Text)
    best_time = Column(Text)
    past_events = Column(Text)
    sentiment_tags = Column(ARRAY(Text))
    source_url = Column(Text)
    image = Column(Text)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    images = relationship('PlaceImage', back_populates='place', cascade='all, delete-orphan')

class PlaceImage(Base):
    __tablename__ = 'place_images'

    id = Column(Integer, primary_key=True, autoincrement=True)
    place_id = Column(String, ForeignKey('places.id', ondelete='CASCADE'), nullable=False)
    url = Column(Text, nullable=False)
    sort_order = Column(Integer, default=0)

    place = relationship('Place', back_populates='images')
