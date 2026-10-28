# WhatsApp Campaign Platform - R&D Documentation

## Executive Summary

This document outlines the research and development findings for building a WhatsApp Campaign Platform that enables users to:
1. Create message templates
2. Submit templates for Meta approval
3. Use approved templates to send bulk WhatsApp campaigns

---

## 1. WhatsApp Business API Overview

### API Choice: WhatsApp Cloud API (Recommended)

Meta offers the **WhatsApp Cloud API** as the only supported solution (On-Premises API was sunset on October 23, 2025).

| Feature | Cloud API |
|---------|-----------|
| **Throughput** | 80-1,000 messages/second per phone number |
| **Hosting** | Meta-hosted (no infrastructure needed) |
| **Uptime** | 99.9% SLA |
| **Latency** | ~5s 99th percentile |
| **Cost** | Per-message pricing only |

### API Endpoints

| Purpose | Endpoint |
|---------|----------|
| Create Template | `POST /{WABA_ID}/message_templates` |
| Get Templates | `GET /{WABA_ID}/message_templates` |
| Update Template | `POST /{TEMPLATE_ID}` |
| Delete Template | `DELETE /{WABA_ID}/message_templates?name={NAME}` |
| Send Message | `POST /{PHONE_NUMBER_ID}/messages` |
| Marketing Messages | `POST /{PHONE_NUMBER_ID}/marketing_messages` |

---

## 2. Template Management

### Template Categories

Meta supports three template categories:

| Category | Use Case | Auto-Approval |
|----------|----------|---------------|
| **MARKETING** | Promotions, offers, newsletters | No |
| **UTILITY** | Order updates, shipping, receipts | No |
| **AUTHENTICATION** | OTP, verification codes | Yes (with OTP buttons) |

### Template Components Structure

Templates consist of four main components:

```json
{
  "name": "order_confirmation",
  "language": "en_US",
  "category": "UTILITY",
  "components": [
    {
      "type": "HEADER",
      "format": "TEXT|IMAGE|VIDEO|DOCUMENT|LOCATION",
      "text": "Order {{1}}"
    },
    {
      "type": "BODY",
      "text": "Hi {{1}}, your order #{{2}} has been confirmed. Expected delivery: {{3}}."
    },
    {
      "type": "FOOTER",
      "text": "Thank you for shopping with us!"
    },
    {
      "type": "BUTTONS",
      "buttons": [
        {
          "type": "URL",
          "text": "Track Order",
          "url": "https://example.com/track/{{1}}"
        },
        {
          "type": "QUICK_REPLY",
          "text": "Contact Support"
        }
      ]
    }
  ]
}
```

### Component Details

#### Header (Optional)
- **Text**: Max 60 characters, 1 variable allowed
- **Media**: IMAGE, VIDEO, DOCUMENT, or LOCATION
- Requires asset handle from Resumable Upload API for media

#### Body (Required)
- Max 1,024 characters
- Multiple variables supported (`{{1}}`, `{{2}}`, etc.)
- Cannot start or end with a variable
- Variables must be sequential

#### Footer (Optional)
- Max 60 characters
- Static text only (no variables)

#### Buttons (Optional)
- Max 10 buttons total
- Types: `URL`, `PHONE_NUMBER`, `QUICK_REPLY`, `COPY_CODE`, `FLOW`, `VOICE_CALL`, `VIDEO_CALL`
- URL buttons support 1 variable in the URL

### Template Creation API

```bash
curl -X POST "https://graph.facebook.com/v26.0/{WABA_ID}/message_templates" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "order_update",
    "language": "en_US",
    "category": "UTILITY",
    "allow_category_change": true,
    "components": [
      {
        "type": "BODY",
        "text": "Your order {{1}} is ready for pickup.",
        "example": {
          "body_text": [["#12345"]]
        }
      }
    ]
  }'
```

**Response:**
```json
{
  "id": "1234567890",
  "status": "PENDING",
  "category": "UTILITY"
}
```

---

## 3. Template Approval Process

### Approval Flow

```
┌─────────────┐     ┌──────────────┐     ┌────────────────┐
│   CREATE    │────▶│   PENDING    │────▶│   APPROVED     │
│  Template   │     │  (Review)    │     │  (Can Send)    │
└─────────────┘     └──────────────┘     └────────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │   REJECTED   │
                    │ (Edit/Appeal)│
                    └──────────────┘
```

### Template Statuses

| Status | Description | Action |
|--------|-------------|--------|
| `PENDING` | Under review | Wait (up to 24 hours) |
| `APPROVED` | Ready to use | Can send messages |
| `REJECTED` | Failed review | Edit and resubmit, or appeal |
| `PAUSED` | Quality issues | Improve quality score |
| `DISABLED` | Low quality | Cannot be used |
| `FLAGGED` | At risk | Improve immediately |
| `ARCHIVED` | Inactive 28+ days | Unarchive to use |

### Common Rejection Reasons

1. **Parameter Formatting Issues**
   - Missing or mismatched curly braces
   - Non-sequential variables (`{{1}}`, `{{3}}` without `{{2}}`)
   - Starting/ending with variables
   - Special characters in variables

2. **Content Violations**
   - Spam or scam-like content
   - Requesting sensitive information (SSN, full card numbers)
   - Threatening or abusive content
   - Violates WhatsApp Commerce Policy

3. **Duplicate Content**
   - Same body/footer as existing template

### Webhook for Status Updates

Subscribe to `message_template_status_update` webhook:

```json
{
  "entry": [{
    "id": "WABA_ID",
    "changes": [{
      "field": "message_template_status_update",
      "value": {
        "event": "APPROVED",
        "message_template_id": 123456789,
        "message_template_name": "order_confirmation",
        "message_template_language": "en_US",
        "message_template_category": "UTILITY"
      }
    }]
  }],
  "object": "whatsapp_business_account"
}
```

---

## 4. Sending Campaign Messages

### Send Template Message API

```bash
curl -X POST "https://graph.facebook.com/v26.0/{PHONE_NUMBER_ID}/messages" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "messaging_product": "whatsapp",
    "recipient_type": "individual",
    "to": "1234567890",
    "type": "template",
    "template": {
      "name": "order_confirmation",
      "language": {
        "code": "en_US"
      },
      "components": [
        {
          "type": "header",
          "parameters": [
            {"type": "text", "text": "ORD-12345"}
          ]
        },
        {
          "type": "body",
          "parameters": [
            {"type": "text", "text": "John"},
            {"type": "text", "text": "ORD-12345"},
            {"type": "text", "text": "Oct 28, 2026"}
          ]
        },
        {
          "type": "button",
          "sub_type": "url",
          "index": "0",
          "parameters": [
            {"type": "text", "text": "ORD-12345"}
          ]
        }
      ]
    }
  }'
```

### Response

```json
{
  "messaging_product": "whatsapp",
  "contacts": [{"input": "1234567890", "wa_id": "1234567890"}],
  "messages": [{"id": "wamid.HBgLMTIzNDU2Nzg5MBUC..."}]
}
```

### Marketing Messages API (Alternative)

For marketing-only campaigns with additional features:

```bash
POST /{PHONE_NUMBER_ID}/marketing_messages
```

Features:
- `product_policy`: `CLOUD_API_FALLBACK` or `STRICT`
- `message_activity_sharing`: Enable/disable read tracking

---

## 5. Rate Limits & Throughput

### Throughput Limits

| Tier | Messages/Second | Condition |
|------|-----------------|-----------|
| Default | 80 MPS | New numbers |
| Upgraded | Up to 1,000 MPS | Automatic upgrade |
| Coexistence | 20 MPS | Shared with WhatsApp app |

### Messaging Limits (Unique Recipients)

| Tier | Unique Users/24h | Requirement |
|------|------------------|-------------|
| Tier 1 | 250 | New verified business |
| Tier 2 | 1,000 | Quality history |
| Tier 3 | 10,000 | Consistent quality |
| Tier 4 | 100,000 | High quality |
| Unlimited | No limit | Excellent quality |

### Handling Rate Limits

```javascript
// Error code 130429 = Rate limit exceeded
// Implement exponential backoff with jitter
const sendWithRetry = async (payload, maxRetries = 5) => {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await sendMessage(payload);
    } catch (error) {
      if (error.code === 130429) {
        const delay = Math.pow(2, i) * 1000 + Math.random() * 1000;
        await sleep(delay);
      } else throw error;
    }
  }
};
```

---

## 6. Pricing Model (As of October 2026)

### Per-Message Pricing

| Category | North America (USD) | Notes |
|----------|---------------------|-------|
| Marketing | $0.02875 | Promotional content |
| Utility | $0.00391 | Transactional updates |
| Authentication | $0.00391 | OTP/verification |
| Service | $0.0034 | Free-form replies |

### Free Messages

1. **Free Entry Point Window**: 72-hour free window when user initiates via Click-to-WhatsApp ads
2. **Service Messages**: First 1,000/month per business phone number
3. **Delivery Charge Only**: Only charged for delivered messages

---

## 7. Authentication & Setup

### Required Permissions

| Permission | Purpose |
|------------|---------|
| `whatsapp_business_messaging` | Send/receive messages |
| `whatsapp_business_management` | Manage templates, numbers |
| `business_management` | Business account access |

### System User Token Setup

1. Go to Meta Business Settings → System Users
2. Create Admin-level System User
3. Assign Full Control to:
   - Your Meta App
   - Your WhatsApp Business Account
4. Generate token with permissions above
5. Set expiration to "Never" for permanent token

### Webhook Setup

```javascript
// Verification endpoint (GET)
app.get('/webhook', (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];
  
  if (mode === 'subscribe' && token === VERIFY_TOKEN) {
    res.status(200).send(challenge);
  } else {
    res.sendStatus(403);
  }
});

// Event handler (POST)
app.post('/webhook', (req, res) => {
  const { entry } = req.body;
  
  for (const e of entry) {
    for (const change of e.changes) {
      if (change.field === 'message_template_status_update') {
        handleTemplateStatusUpdate(change.value);
      }
    }
  }
  
  res.sendStatus(200);
});
```

---

## 8. Proposed Platform Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (Next.js)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  Template    │  │  Campaign    │  │   Analytics          │  │
│  │  Builder     │  │  Manager     │  │   Dashboard          │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Backend API                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  Template    │  │  Campaign    │  │   Webhook            │  │
│  │  Service     │  │  Service     │  │   Handler            │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌──────────────────┐  ┌──────────────┐  ┌──────────────────────┐
│    Database      │  │  Message     │  │   Meta WhatsApp      │
│   (PostgreSQL)   │  │  Queue       │  │   Cloud API          │
│                  │  │  (Redis/SQS) │  │                      │
└──────────────────┘  └──────────────┘  └──────────────────────┘
```

### Database Schema

```sql
-- Users & Authentication
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE,
  waba_id VARCHAR(100),
  phone_number_id VARCHAR(100),
  access_token_encrypted TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Templates
CREATE TABLE templates (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  meta_template_id VARCHAR(100),
  name VARCHAR(512),
  language VARCHAR(10),
  category VARCHAR(50),
  status VARCHAR(50) DEFAULT 'DRAFT',
  components JSONB,
  rejection_reason TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Campaigns
CREATE TABLE campaigns (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  template_id UUID REFERENCES templates(id),
  name VARCHAR(255),
  status VARCHAR(50) DEFAULT 'DRAFT',
  scheduled_at TIMESTAMP,
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  total_recipients INT DEFAULT 0,
  sent_count INT DEFAULT 0,
  delivered_count INT DEFAULT 0,
  failed_count INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Campaign Recipients
CREATE TABLE campaign_recipients (
  id UUID PRIMARY KEY,
  campaign_id UUID REFERENCES campaigns(id),
  phone_number VARCHAR(20),
  parameters JSONB,
  status VARCHAR(50) DEFAULT 'PENDING',
  message_id VARCHAR(255),
  error_code VARCHAR(50),
  error_message TEXT,
  sent_at TIMESTAMP,
  delivered_at TIMESTAMP
);

-- Webhook Events
CREATE TABLE webhook_events (
  id UUID PRIMARY KEY,
  event_type VARCHAR(100),
  payload JSONB,
  processed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Key Features

1. **Template Builder**
   - Visual editor for creating templates
   - Real-time preview
   - Variable management
   - Media upload support
   - Validation before submission

2. **Template Management**
   - Submit to Meta for approval
   - Track approval status via webhooks
   - Edit rejected templates
   - Archive/unarchive templates

3. **Campaign Manager**
   - Upload recipient lists (CSV/Excel)
   - Map variables to data columns
   - Schedule campaigns
   - Rate-limited bulk sending
   - Real-time progress tracking

4. **Analytics Dashboard**
   - Delivery rates
   - Read rates (if enabled)
   - Failed message analysis
   - Cost tracking

---

## 9. Implementation Considerations

### Security
- Encrypt access tokens at rest
- Use HTTPS everywhere
- Implement webhook signature verification
- Rate limit API endpoints

### Scalability
- Use message queues for bulk sending
- Implement worker pools for parallel processing
- Database connection pooling
- Caching for template data

### Compliance
- Store user consent records
- Provide opt-out mechanisms
- Respect quiet hours
- Comply with GDPR/local regulations

### Error Handling
- Implement circuit breakers
- Log all API interactions
- Alert on high failure rates
- Automatic retry with backoff

---

## 10. Next Steps

1. **Phase 1: MVP**
   - Basic template builder (text-only)
   - Single-language support
   - Submit and track approval
   - Simple campaign sending

2. **Phase 2: Enhanced**
   - Media templates (image, video, document)
   - Multi-language support
   - Scheduled campaigns
   - Basic analytics

3. **Phase 3: Advanced**
   - A/B testing
   - Advanced analytics
   - Team collaboration
   - API access for customers

---

## Appendix: Useful Links

- [WhatsApp Cloud API Get Started](https://developers.facebook.com/docs/whatsapp/cloud-api/get-started/)
- [Message Templates API](https://developers.facebook.com/docs/whatsapp/business-management-api/message-templates/)
- [Template Components Guide](https://developers.facebook.com/docs/whatsapp/business-management-api/message-templates/components)
- [Template Review Process](https://developers.facebook.com/documentation/business-messaging/whatsapp/templates/template-review)
- [Send Messages API](https://developers.facebook.com/docs/whatsapp/cloud-api/reference/messages/)
- [Webhooks Setup](https://developers.facebook.com/docs/whatsapp/business-management-api/webhooks/components/)
- [Pricing Documentation](https://developers.facebook.com/documentation/business-messaging/whatsapp/pricing)
- [Error Codes Reference](https://developers.facebook.com/docs/whatsapp/cloud-api/support/error-codes/)
