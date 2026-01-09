# TASCO - Billing Application

A professional Flutter-based billing application designed to streamline invoice generation and management for T.A. Sitabkhan.

## Features

### 📋 Stock Management

- **Add Stock Items**: Easily add new products to your inventory with name and price
- **Edit Items**: Modify existing item names and prices
- **Delete Items**: Remove items from inventory
- **View All Items**: Browse all stock items in a user-friendly list

### 💰 Bill Creation

- **Create Bills**: Generate bills by selecting items from stock
- **Real-time Search**: Search for items by name with instant filtering
- **Custom Pricing**: Override item prices for specific bills
- **Quantity Input**: Set custom quantities for each item
- **Bill Preview**: View all items added to the current bill with totals

### 📄 Invoice Generation

- **Professional PDFs**: Generate formatted PDF invoices
- **Invoice Details**:
  - Company name (T.A. Sitabkhan)
  - Invoice date in YYYY-MM-DD format
  - Itemized table with Qty, Price, and Total
  - Subtotal calculation
  - Packing cost option with user confirmation
  - Grand total with packing cost included
- **Share Invoices**: Directly share generated PDFs via email, messaging, or storage
- **Date Tracking**: Automatic invoice date stamping

### 🎨 User Interface

- **Purple Theme**: Elegant and professional color scheme
- **Responsive Design**: Optimized for mobile devices
- **Intuitive Navigation**: Easy switching between stock management and bill creation
- **Accessibility**: Clear labels and icons for all functions

## Getting Started

### Prerequisites

- Flutter SDK (3.0 or later)
- Dart 3.0 or later
- Android Studio or Xcode (for mobile development)

### Installation

1. **Clone the repository**

   ```bash
   cd billing_app_sitabkhan
   ```

2. **Get dependencies**

   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### For Android

```bash
flutter run -d android
```

### For iOS

```bash
flutter run -d ios
```

## Project Structure

```
lib/
├── main.dart                 # App entry point and theme configuration
├── db/
│   └── database.dart         # SQLite database setup and management
├── models/
│   ├── item.dart            # Stock item model
│   └── bill_item.dart       # Bill item model with quantities
├── screens/
│   ├── items_screen.dart    # Stock management interface
│   └── create_bill_screen.dart # Bill creation interface
└── utils/
    └── pdf_generator.dart    # PDF invoice generation
```

## Dependencies

### Core

- **flutter**: UI framework
- **flutter_test**: Testing utilities
- **sqflite**: Local SQLite database
- **path_provider**: File system access

### PDF & Sharing

- **pdf**: PDF generation and manipulation
- **share_plus**: Native sharing functionality

## App Theme

The application uses a custom purple theme:

- **Primary Color**: #7C4DFF (Subtle Purple)
- **Material Design 3**: Modern Google design principles

## Database Schema

### Items Table

```sql
CREATE TABLE items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  price REAL NOT NULL
);
```

## Features in Detail

### Stock Items Page

- Add new items with name and price
- Search items by name (hidden until typing)
- Edit item details with confirmation dialog
- Delete items with visual feedback
- View full list with prices

### Create Bill Page

- Search and filter items from stock
- Add selected items with custom quantity and price
- View bill preview with item-by-item breakdown
- Fixed bottom total display
- Generate PDF invoice with optional packing cost
- Share invoice directly to other apps

### PDF Invoice

- Professional layout on A4 size
- Company branding (T.A. Sitabkhan)
- Timestamp (Invoice Date)
- Detailed item table
- Subtotal and grand total calculations
- Optional packing cost display
- Print-ready format

## Usage Guide

### Adding Stock Items

1. Navigate to Stock Items page
2. Enter item name and price
3. Tap "Add Item"
4. Item appears in the list below

### Creating a Bill

1. Go to Create Bill (via the receipt icon)
2. Search for items using the search bar
3. Select an item from results
4. Enter quantity and optional custom price
5. Tap "Add Item"
6. Repeat for additional items
7. Review total at the bottom
8. Tap "Generate & Share Bill"

### Generating Invoices

1. After creating your bill, tap "Generate & Share Bill"
2. If prompted, enter packing cost (optional)
3. PDF is generated and share menu appears
4. Choose how to share (Email, WhatsApp, Save, etc.)

## Platform Support

- ✅ **Android**: Tested on Android 8.0+
- ✅ **iOS**: Tested on iOS 11+
- ✅ **Web**: Can be built for web (not optimized)
- ✅ **Windows**: Can be built for Windows (not optimized)

## App Settings

The app stores all data locally:

- Stock items in SQLite database
- Generated PDFs in application documents directory
- No cloud synchronization required

## Future Enhancements

- Invoice history and tracking
- Customer information in invoices
- Multiple currency support
- Discount and tax calculations
- Bill templates and customization
- Cloud backup and sync
- Analytics and reporting

## Troubleshooting

### App not starting

- Clear build cache: `flutter clean`
- Rebuild: `flutter pub get && flutter run`

### Database errors

- Delete app and reinstall
- Database is reset on first launch

### PDF not generating

- Ensure write permissions are granted
- Check storage space availability
- Verify all required packages are installed

## Support

For issues or feature requests, please contact T.A. Sitabkhan.

## License

Proprietary - T.A. Sitabkhan

## Version

**Current Version**: 1.0.0

---

**Last Updated**: January 2026
**App Name**: TASCO
