# Pantry repository for managing pantry items
from app.db.firebase_client import firebase_client
from typing import List, Optional
from datetime import datetime


class PantryItem:
    """Model for pantry items"""
    def __init__(self, id: str, user_id: str, name: str, quantity: str, category: str = "", expiry_date: Optional[str] = None):
        self.id = id
        self.user_id = user_id
        self.name = name
        self.quantity = quantity
        self.category = category
        self.expiry_date = expiry_date
        self.created_at = datetime.utcnow()


class PantryRepository:
    """Repository for managing user pantry items"""
    def __init__(self):
        self.db = firebase_client.get_firestore_client()
        self.collection = self.db.collection('pantry')

    def add_item(self, user_id: str, name: str, quantity: str, category: str = "", expiry_date: Optional[str] = None) -> PantryItem:
        """Add an item to the user's pantry"""
        try:
            item_data = {
                'user_id': user_id,
                'name': name,
                'quantity': quantity,
                'category': category,
                'expiry_date': expiry_date,
                'created_at': datetime.utcnow(),
                'updated_at': datetime.utcnow()
            }
            
            doc_ref = self.collection.document()
            doc_ref.set(item_data)
            
            return PantryItem(doc_ref.id, user_id, name, quantity, category, expiry_date)
        except Exception as e:
            raise Exception(f"Failed to add pantry item: {str(e)}")

    def get_pantry_items(self, user_id: str) -> List[PantryItem]:
        """Get all pantry items for a user"""
        try:
            docs = self.collection.where('user_id', '==', user_id).get()
            items = []
            for doc in docs:
                data = doc.to_dict()
                item = PantryItem(
                    doc.id,
                    data.get('user_id'),
                    data.get('name'),
                    data.get('quantity'),
                    data.get('category', ''),
                    data.get('expiry_date')
                )
                items.append(item)
            return items
        except Exception as e:
            raise Exception(f"Failed to get pantry items: {str(e)}")

    def get_pantry_item(self, item_id: str) -> Optional[PantryItem]:
        """Get a specific pantry item by ID"""
        try:
            doc = self.collection.document(item_id).get()
            if doc.exists:
                data = doc.to_dict()
                return PantryItem(
                    doc.id,
                    data.get('user_id'),
                    data.get('name'),
                    data.get('quantity'),
                    data.get('category', ''),
                    data.get('expiry_date')
                )
            return None
        except Exception as e:
            raise Exception(f"Failed to get pantry item: {str(e)}")

    def update_item(self, item_id: str, **kwargs) -> Optional[PantryItem]:
        """Update a pantry item"""
        try:
            update_data = {k: v for k, v in kwargs.items() if v is not None}
            update_data['updated_at'] = datetime.utcnow()
            
            self.collection.document(item_id).update(update_data)
            return self.get_pantry_item(item_id)
        except Exception as e:
            raise Exception(f"Failed to update pantry item: {str(e)}")

    def delete_item(self, item_id: str) -> bool:
        """Delete a pantry item"""
        try:
            self.collection.document(item_id).delete()
            return True
        except Exception as e:
            raise Exception(f"Failed to delete pantry item: {str(e)}")


# Global instance
pantry_repository = PantryRepository()
