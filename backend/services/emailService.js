// -----------------------------------------------------------------------------
// Email Service for Care Connect
// -----------------------------------------------------------------------------
// Features:
// - Professional sender name ("Care Connect")
// - Modern HTML email templates
// - OTP verification, registration, identity verification, approval
// -----------------------------------------------------------------------------

const nodemailer = require("nodemailer");

// --- Nodemailer Transporter ---
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

// --- Email Templates ---
const templates = {
  verifyEmailOTP: (name, otp, role) => {
    // Role is already formatted in the controller, use it directly
    const displayRole = role || 'User';
      
    return `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; background-color: #1a1a1a; color: #ffffff; border-radius: 10px;">
      <div style="text-align: center; margin-bottom: 30px;">
        <h1 style="color: #ff8c42; margin: 0; font-size: 28px;">Email Verification - Care Connect</h1>
      </div>
      
      <div style="background-color: #2a2a2a; padding: 25px; border-radius: 8px; margin-bottom: 20px;">
        <p style="margin: 0 0 15px 0; font-size: 16px;">Hi ${name},</p>
        <p style="margin: 0 0 20px 0; font-size: 16px;">
          Thank you for registering with Care Connect as a <strong style="color: #ff8c42;">${displayRole}</strong>. 
          Here's your verification code:
        </p>
        
        <div style="text-align: center; margin: 25px 0;">
          <div style="background-color: #ff8c42; color: #1a1a1a; padding: 20px; border-radius: 8px; font-size: 32px; font-weight: bold; letter-spacing: 8px; display: inline-block;">
            ${otp}
          </div>
        </div>
        
        <p style="margin: 20px 0 0 0; font-size: 14px; color: #cccccc;">
          Enter this code in your mobile app to complete your registration.
        </p>
      </div>
      
      <div style="background-color: #3a3a0a; padding: 15px; border-radius: 6px; border-left: 4px solid #ffcc00;">
        <p style="margin: 0; font-size: 14px; color: #ffcc00;">
          <strong>⚠️ Important:</strong> This code expires in 10 minutes.
        </p>
      </div>
      
      <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #444;">
        <p style="margin: 0; font-size: 12px; color: #888;">
          &mdash; <em>Care Connect Team</em>
        </p>
      </div>
    </div>
  `},

  registrationSuccess: (name, role) => `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; background-color: #1a1a1a; color: #ffffff; border-radius: 10px;">
      <div style="text-align: center; margin-bottom: 30px;">
        <h1 style="color: #ff8c42; margin: 0; font-size: 28px;">Welcome to Care Connect</h1>
      </div>
      
      <div style="background-color: #2a2a2a; padding: 25px; border-radius: 8px; margin-bottom: 20px;">
        <p style="margin: 0 0 15px 0; font-size: 16px;">Dear <strong style="color: #ff8c42;">${name}</strong>,</p>
        <p style="margin: 0 0 20px 0; font-size: 16px;">
          Welcome to Care Connect! Your registration as a <strong style="color: #ff8c42;">${role}</strong> has been successfully completed.
        </p>
        <p style="margin: 0 0 20px 0; font-size: 16px;">
          You can now access all features available to your role and start making a difference in your community.
        </p>
      </div>
      
      <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #444;">
        <p style="margin: 0; font-size: 12px; color: #888;">
          &mdash; <em>Care Connect Team</em>
        </p>
      </div>
    </div>
  `,

  paymentSuccess: (name, amount, role) => `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; background-color: #1a1a1a; color: #ffffff; border-radius: 10px;">
      <div style="text-align: center; margin-bottom: 30px;">
        <h1 style="color: #ff8c42; margin: 0; font-size: 28px;">Payment Confirmed - Care Connect</h1>
      </div>
      
      <div style="background-color: #2a2a2a; padding: 25px; border-radius: 8px; margin-bottom: 20px;">
        <p style="margin: 0 0 15px 0; font-size: 16px;">Hi ${name},</p>
        <p style="margin: 0 0 20px 0; font-size: 16px;">
          Your payment of <strong style="color: #00cc00;">Rs. ${amount}</strong> has been successfully processed.
        </p>
        <p style="margin: 0 0 20px 0; font-size: 16px;">
          Please verify your email to complete the registration process.
        </p>
      </div>
      
      <div style="background-color: #0a3a0a; padding: 15px; border-radius: 6px; border-left: 4px solid #00cc00;">
        <p style="margin: 0; font-size: 14px; color: #00cc00;">
          <strong>✓ Payment Status:</strong> Completed Successfully
        </p>
      </div>
      
      <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #444;">
        <p style="margin: 0; font-size: 12px; color: #888;">
          &mdash; <em>Care Connect Team</em>
        </p>
      </div>
    </div>
  `,

  identityVerificationRequest: (name) => `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; background-color: #1a1a1a; color: #ffffff; border-radius: 10px;">
      <div style="text-align: center; margin-bottom: 30px;">
        <h1 style="color: #ff8c42; margin: 0; font-size: 28px;">Identity Verification Required - Care Connect</h1>
      </div>
      
      <div style="background-color: #2a2a2a; padding: 25px; border-radius: 8px; margin-bottom: 20px;">
        <p style="margin: 0 0 15px 0; font-size: 16px;">Hi ${name},</p>
        <p style="margin: 0 0 20px 0; font-size: 16px;">
          To complete your Care Connect registration, please upload your CNIC images for identity verification.
        </p>
        <p style="margin: 0 0 20px 0; font-size: 16px;">
          This step ensures the safety and security of our community members.
        </p>
      </div>
      
      <div style="background-color: #3a3a0a; padding: 15px; border-radius: 6px; border-left: 4px solid #ffcc00;">
        <p style="margin: 0; font-size: 14px; color: #ffcc00;">
          <strong>Required:</strong> Please upload clear photos of both sides of your CNIC.
        </p>
      </div>
      
      <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #444;">
        <p style="margin: 0; font-size: 12px; color: #888;">
          &mdash; <em>Care Connect Team</em>
        </p>
      </div>
    </div>
  `,

  identityApproved: (name) => `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; background-color: #1a1a1a; color: #ffffff; border-radius: 10px;">
      <div style="text-align: center; margin-bottom: 30px;">
        <h1 style="color: #ff8c42; margin: 0; font-size: 28px;">Identity Verified - Care Connect</h1>
      </div>
      
      <div style="background-color: #2a2a2a; padding: 25px; border-radius: 8px; margin-bottom: 20px;">
        <p style="margin: 0 0 15px 0; font-size: 16px;">Congratulations ${name}!</p>
        <p style="margin: 0 0 20px 0; font-size: 16px;">
          Your identity has been successfully verified by our management team. Your dashboard will update shortly, and you will perform your actions freely using the app.
        </p>
        <p style="margin: 0 0 20px 0; font-size: 16px;">
          Thank you for your cooperation.
        </p>
      </div>
      
      <div style="background-color: #0a3a0a; padding: 15px; border-radius: 6px; border-left: 4px solid #00cc00;">
        <p style="margin: 0; font-size: 14px; color: #00cc00;">
          <strong>✓ Verification Status:</strong> Approved
        </p>
      </div>
      
      <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #444;">
        <p style="margin: 0; font-size: 12px; color: #888;">
          &mdash; <em>Care Connect Team</em>
        </p>
      </div>
    </div>
  `,

  identityRejected: (name, reason) => `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; background-color: #1a1a1a; color: #ffffff; border-radius: 10px;">
      <div style="text-align: center; margin-bottom: 30px;">
        <h1 style="color: #ff8c42; margin: 0; font-size: 28px;">Identity Verification Update - Care Connect</h1>
      </div>
      
      <div style="background-color: #2a2a2a; padding: 25px; border-radius: 8px; margin-bottom: 20px;">
        <p style="margin: 0 0 15px 0; font-size: 16px;">Hi ${name},</p>
        <p style="margin: 0 0 20px 0; font-size: 16px;">
          We were unable to verify your identity with the submitted documents.
        </p>
        <p style="margin: 0 0 20px 0; font-size: 16px;">
          <strong>Reason:</strong> ${reason}
        </p>
        <p style="margin: 0 0 20px 0; font-size: 16px;">
          Please resubmit clear, high-quality images of your CNIC for verification.
        </p>
      </div>
      
      <div style="background-color: #3a0a0a; padding: 15px; border-radius: 6px; border-left: 4px solid #cc0000;">
        <p style="margin: 0; font-size: 14px; color: #cc0000;">
          <strong>✗ Verification Status:</strong> Rejected
        </p>
      </div>
      
      <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #444;">
        <p style="margin: 0; font-size: 12px; color: #888;">
          &mdash; <em>Care Connect Team</em>
        </p>
      </div>
    </div>
  `,

  passwordReset: (name, resetLink) => `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; background-color: #1a1a1a; color: #ffffff; border-radius: 10px;">
      <div style="text-align: center; margin-bottom: 30px;">
        <h1 style="color: #ff8c42; margin: 0; font-size: 28px;">Password Reset - Care Connect</h1>
      </div>
      
      <div style="background-color: #2a2a2a; padding: 25px; border-radius: 8px; margin-bottom: 20px;">
        <p style="margin: 0 0 15px 0; font-size: 16px;">Hi ${name},</p>
        <p style="margin: 0 0 20px 0; font-size: 16px;">
          You requested a password reset for your Care Connect account.
        </p>
        <p style="margin: 0 0 20px 0; font-size: 16px;">
          Click the button below to reset your password:
        </p>
        
        <div style="text-align: center; margin: 25px 0;">
          <a href="${resetLink}" style="background-color: #ff8c42; color: #1a1a1a; padding: 15px 30px; border-radius: 8px; text-decoration: none; font-weight: bold; display: inline-block;">
            Reset Password
          </a>
        </div>
        
        <p style="margin: 20px 0 0 0; font-size: 14px; color: #cccccc;">
          If you didn't request this reset, please ignore this email.
        </p>
      </div>
      
      <div style="background-color: #3a3a0a; padding: 15px; border-radius: 6px; border-left: 4px solid #ffcc00;">
        <p style="margin: 0; font-size: 14px; color: #ffcc00;">
          <strong>⚠️ Security:</strong> This link expires in 1 hour for your security.
        </p>
      </div>
      
      <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #444;">
        <p style="margin: 0; font-size: 12px; color: #888;">
          &mdash; <em>Care Connect Team</em>
        </p>
      </div>
    </div>
  `,
};

/**
 * Send an email with flexible parameter handling
 * @param {string|Object} to - Recipient email address OR options object
 * @param {string} subject - Email subject (if first param is string)
 * @param {string} templateKey - Template key OR HTML content
 * @param {Object} data - Data to populate the template
 * @returns {Promise<Object>} - Success status and message ID
 */
const sendEmail = async (to, subject, templateKey, data = {}) => {
  try {
    console.log('📧 EMAIL SERVICE - Starting sendEmail');
    
    // Handle both old format (individual params) and new format (options object)
    let recipient, emailSubject, htmlContent;
    
    if (typeof to === 'object' && to.to) {
      // New format: sendEmail({ to, subject, html })
      recipient = to.to;
      emailSubject = to.subject;
      htmlContent = to.html;
      console.log('📧 Using new format (options object)');
    } else {
      // Old format: sendEmail(to, subject, templateKey, data)
      recipient = to;
      emailSubject = subject;
      
      const template = templates[templateKey];
      if (!template) {
        // If no template found, assume templateKey is raw HTML
        htmlContent = templateKey;
      } else {
        // Use template
        switch (templateKey) {
          case 'verifyEmailOTP':
            htmlContent = template(data.name, data.otp, data.role);
            break;
          case 'registrationSuccess':
            htmlContent = template(data.name, data.role);
            break;
          case 'paymentSuccess':
            htmlContent = template(data.name, data.amount, data.role);
            break;
          case 'identityVerificationRequest':
            htmlContent = template(data.name);
            break;
          case 'identityApproved':
            htmlContent = template(data.name);
            break;
          case 'identityRejected':
            htmlContent = template(data.name, data.reason);
            break;
          case 'passwordReset':
            htmlContent = template(data.name, data.resetLink);
            break;
          default:
            htmlContent = template(data.name, data.otp || data.amount || data.role || data.resetLink || data.reason);
        }
      }
      console.log('📧 Using old format (individual params)');
    }
    
    console.log('📧 Recipient email:', recipient);
    console.log('📧 Email subject:', emailSubject);
    
    const mailOptions = {
      from: `"Care Connect" <${process.env.EMAIL_USER}>`,
      to: recipient,
      subject: emailSubject.startsWith('Care Connect') ? emailSubject : `Care Connect - ${emailSubject}`,
      html: htmlContent,
    };

    console.log('📧 Email from:', `"Care Connect" <${process.env.EMAIL_USER}>`);
    console.log('📧 Email to:', recipient);
    
    console.log('📧 Attempting to send email via transporter...');
    const info = await transporter.sendMail(mailOptions);
    console.log('✅ Email sent successfully! Result:', info);
    console.log(`✅ Email sent to ${recipient}`);
    
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('💥 CRITICAL EMAIL ERROR:', error);
    console.error('💥 Error details:', {
      message: error.message,
      code: error.code,
      command: error.command,
      response: error.response
    });
    throw error;
  }
};

// Send donation verified email
const sendDonationVerifiedEmail = async (email, data) => {
  try {
    console.log('📧 EMAIL SERVICE - Starting sendDonationVerifiedEmail');
    console.log('📧 Recipient email:', email);
    console.log('📧 Email data:', data);
    
    const { donorName, donationTitle, verifiedAt } = data;
    
    const subject = '✅ Your Donation Has Been Verified!';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #4CAF50, #45a049); color: white; padding: 30px; border-radius: 10px; text-align: center;">
          <h1 style="margin: 0; font-size: 28px;">🎉 Donation Verified!</h1>
        </div>
        
        <div style="background: #f9f9f9; padding: 30px; border-radius: 10px; margin: 20px 0;">
          <h2 style="color: #333; margin-top: 0;">Hello ${donorName},</h2>
          
          <p style="font-size: 16px; line-height: 1.6; color: #555;">
            Great news! Your donation has been successfully verified by our admin team.
          </p>
          
          <div style="background: white; padding: 20px; border-radius: 8px; border-left: 4px solid #4CAF50;">
            <h3 style="color: #4CAF50; margin-top: 0;">Donation Details:</h3>
            <p><strong>Title:</strong> ${donationTitle}</p>
            <p><strong>Verified At:</strong> ${new Date(verifiedAt).toLocaleString()}</p>
            <p><strong>Status:</strong> <span style="color: #4CAF50; font-weight: bold;">✅ VERIFIED</span></p>
          </div>
          
          <p style="font-size: 16px; line-height: 1.6; color: #555;">
            Your donation is now live and available for requesters. You can track its status on your dashboard.
          </p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${process.env.FRONTEND_URL}/donor/dashboard" 
               style="background: #4CAF50; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; font-weight: bold;">
              View Dashboard
            </a>
          </div>
        </div>
        
        <div style="text-align: center; color: #888; font-size: 14px;">
          <p>Thank you for helping reduce food waste! 🌱</p>
          <p>Care Connect Team</p>
        </div>
      </div>
    `;
    
    console.log('📧 Email subject:', subject);
    console.log('📧 Email from:', `"Care Connect" <${process.env.EMAIL_USER}>`);
    console.log('📧 Email to:', email);
    
    const mailOptions = {
      from: `"Care Connect" <${process.env.EMAIL_USER}>`,
      to: email,
      subject: subject,
      html: html,
    };

    console.log('📧 Attempting to send email via transporter...');
    const result = await transporter.sendMail(mailOptions);
    console.log('✅ Email sent successfully! Result:', result);
    console.log(`✅ Donation verified email sent to ${email}`);
    
    return result;
  } catch (error) {
    console.error('💥 CRITICAL EMAIL ERROR:', error);
    console.error('💥 Error details:', {
      message: error.message,
      code: error.code,
      command: error.command,
      response: error.response
    });
    throw error;
  }
};

// Send donation rejected email
const sendDonationRejectedEmail = async (email, data) => {
  try {
    console.log('📧 EMAIL SERVICE - Starting sendDonationRejectedEmail');
    console.log('📧 Recipient email:', email);
    console.log('📧 Email data:', data);
    
    const { donorName, donationTitle, rejectionReason } = data;
    
    const subject = '❌ Donation Verification Update';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #f44336, #d32f2f); color: white; padding: 30px; border-radius: 10px; text-align: center;">
          <h1 style="margin: 0; font-size: 28px;">Donation Verification Update</h1>
        </div>
        
        <div style="background: #f9f9f9; padding: 30px; border-radius: 10px; margin: 20px 0;">
          <h2 style="color: #333; margin-top: 0;">Hello ${donorName},</h2>
          
          <p style="font-size: 16px; line-height: 1.6; color: #555;">
            We've reviewed your donation submission, but unfortunately it couldn't be verified at this time.
          </p>
          
          <div style="background: white; padding: 20px; border-radius: 8px; border-left: 4px solid #f44336;">
            <h3 style="color: #f44336; margin-top: 0;">Donation Details:</h3>
            <p><strong>Title:</strong> ${donationTitle}</p>
            <p><strong>Status:</strong> <span style="color: #f44336; font-weight: bold;">❌ NOT VERIFIED</span></p>
            <p><strong>Reason:</strong> ${rejectionReason}</p>
          </div>
          
          <p style="font-size: 16px; line-height: 1.6; color: #555;">
            Please review the feedback above and feel free to create a new donation that addresses these concerns.
          </p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${process.env.FRONTEND_URL}/donor/donate" 
               style="background: #4CAF50; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; font-weight: bold;">
              Create New Donation
            </a>
          </div>
        </div>
        
        <div style="text-align: center; color: #888; font-size: 14px;">
          <p>If you have questions, please contact our support team.</p>
          <p>Care Connect Team</p>
        </div>
      </div>
    `;
    
    console.log('📧 Email subject:', subject);
    console.log('📧 Email from:', `"Care Connect" <${process.env.EMAIL_USER}>`);
    console.log('📧 Email to:', email);
    
    const mailOptions = {
      from: `"Care Connect" <${process.env.EMAIL_USER}>`,
      to: email,
      subject: subject,
      html: html,
    };

    console.log('📧 Attempting to send email via transporter...');
    const result = await transporter.sendMail(mailOptions);
    console.log('✅ Email sent successfully! Result:', result);
    console.log(`✅ Donation rejected email sent to ${email}`);
    
    return result;
  } catch (error) {
    console.error('💥 CRITICAL EMAIL ERROR:', error);
    console.error('💥 Error details:', {
      message: error.message,
      code: error.code,
      command: error.command,
      response: error.response
    });
    throw error;
  }
};

// Send donation submitted email to donor
const sendDonationSubmittedEmail = async (email, data) => {
  try {
    console.log('📧 EMAIL SERVICE - Starting sendDonationSubmittedEmail');
    console.log('📧 Recipient email:', email);
    console.log('📧 Email data:', data);
    
    const { donorName, donationTitle, donationId, submissionDate } = data;
    
    const subject = '📝 Donation Submitted Successfully';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #2196F3, #1976D2); color: white; padding: 30px; border-radius: 10px; text-align: center;">
          <h1 style="margin: 0; font-size: 28px;">📝 Donation Submitted!</h1>
        </div>
        
        <div style="background: #f9f9f9; padding: 30px; border-radius: 10px; margin: 20px 0;">
          <h2 style="color: #333; margin-top: 0;">Hello ${donorName},</h2>
          
          <p style="font-size: 16px; line-height: 1.6; color: #555;">
            Thank you for submitting your donation! We've received your submission and it's now under review.
          </p>
          
          <div style="background: white; padding: 20px; border-radius: 8px; border-left: 4px solid #2196F3;">
            <h3 style="color: #2196F3; margin-top: 0;">Donation Details:</h3>
            <p><strong>Title:</strong> ${donationTitle}</p>
            <p><strong>Donation ID:</strong> ${donationId}</p>
            <p><strong>Submitted:</strong> ${new Date(submissionDate).toLocaleString()}</p>
            <p><strong>Status:</strong> <span style="color: #FF9800; font-weight: bold;">⏳ PENDING VERIFICATION</span></p>
          </div>
          
          <p style="font-size: 16px; line-height: 1.6; color: #555;">
            Our admin team will review your donation within 24 hours. You'll receive an email notification once it's verified.
          </p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${process.env.FRONTEND_URL}/donor/dashboard" 
               style="background: #2196F3; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; font-weight: bold;">
              View Dashboard
            </a>
          </div>
        </div>
        
        <div style="text-align: center; color: #888; font-size: 14px;">
          <p>Thank you for helping reduce food waste! 🌱</p>
          <p>Care Connect Team</p>
        </div>
      </div>
    `;
    
    const mailOptions = {
      from: `"Care Connect" <${process.env.EMAIL_USER}>`,
      to: email,
      subject: subject,
      html: html,
    };

    const result = await transporter.sendMail(mailOptions);
    console.log('✅ Donation submitted email sent successfully');
    return result;
  } catch (error) {
    console.error('💥 Error sending donation submitted email:', error);
    throw error;
  }
};

// Send new donation notification to admin
const sendNewDonationNotificationEmail = async (email, data) => {
  try {
    console.log('📧 EMAIL SERVICE - Starting sendNewDonationNotificationEmail');
    console.log('📧 Recipient email:', email);
    console.log('📧 Email data:', data);
    
    const { adminName, donorName, donationTitle, donationId, submissionDate } = data;
    
    const subject = '🔔 New Donation Requires Verification';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: linear-gradient(135deg, #FF9800, #F57C00); color: white; padding: 30px; border-radius: 10px; text-align: center;">
          <h1 style="margin: 0; font-size: 28px;">🔔 New Donation Alert</h1>
        </div>
        
        <div style="background: #f9f9f9; padding: 30px; border-radius: 10px; margin: 20px 0;">
          <h2 style="color: #333; margin-top: 0;">Hello ${adminName},</h2>
          
          <p style="font-size: 16px; line-height: 1.6; color: #555;">
            A new donation has been submitted and requires your verification.
          </p>
          
          <div style="background: white; padding: 20px; border-radius: 8px; border-left: 4px solid #FF9800;">
            <h3 style="color: #FF9800; margin-top: 0;">Donation Details:</h3>
            <p><strong>Donor:</strong> ${donorName}</p>
            <p><strong>Title:</strong> ${donationTitle}</p>
            <p><strong>Donation ID:</strong> ${donationId}</p>
            <p><strong>Submitted:</strong> ${new Date(submissionDate).toLocaleString()}</p>
            <p><strong>Status:</strong> <span style="color: #FF9800; font-weight: bold;">⏳ AWAITING VERIFICATION</span></p>
          </div>
          
          <p style="font-size: 16px; line-height: 1.6; color: #555;">
            Please review this donation in the admin panel and approve or reject it with appropriate feedback.
          </p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${process.env.ADMIN_URL || 'http://localhost:5173'}/donation-verification" 
               style="background: #FF9800; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; font-weight: bold;">
              Review Donation
            </a>
          </div>
        </div>
        
        <div style="text-align: center; color: #888; font-size: 14px;">
          <p>Care Connect Admin System</p>
        </div>
      </div>
    `;
    
    const mailOptions = {
      from: `"Care Connect Admin" <${process.env.EMAIL_USER}>`,
      to: email,
      subject: subject,
      html: html,
    };

    const result = await transporter.sendMail(mailOptions);
    console.log('✅ Admin notification email sent successfully');
    return result;
  } catch (error) {
    console.error('💥 Error sending admin notification email:', error);
    throw error;
  }
};
// Send request verified email
const sendRequestVerifiedEmail = async (email, data) => {
  try {
    const { requesterName, requestTitle, verifiedAt } = data;
    const subject = '✅ Your Request Has Been Approved!';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #28a745;">Request Approved! 🎉</h2>
        <p>Dear ${requesterName},</p>
        <p>Great news! Your request "<strong>${requestTitle}</strong>" has been approved by our admin team.</p>
        <p>Your request is now visible to donors and volunteers who can help fulfill it.</p>
        <p>Approved on: ${new Date(verifiedAt).toLocaleDateString()}</p>
        <p>Thank you for using Care Connect!</p>
      </div>
    `;
    
    const mailOptions = {
      from: `"Care Connect" <${process.env.EMAIL_USER}>`,
      to: email,
      subject: subject,
      html: html,
    };

    const result = await transporter.sendMail(mailOptions);
    console.log(`✅ Request verified email sent to ${email}`);
    return result;
  } catch (error) {
    console.error('💥 Error sending request verified email:', error);
    throw error;
  }
};

// Send request rejected email
const sendRequestRejectedEmail = async (email, data) => {
  try {
    const { requesterName, requestTitle, rejectionReason } = data;
    const subject = '❌ Request Update Required';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #dc3545;">Request Needs Revision</h2>
        <p>Dear ${requesterName},</p>
        <p>Your request "<strong>${requestTitle}</strong>" requires some updates before approval.</p>
        <p><strong>Reason:</strong> ${rejectionReason}</p>
        <p>Please review and resubmit your request with the necessary corrections.</p>
        <p>Thank you for your understanding!</p>
      </div>
    `;
    
    const mailOptions = {
      from: `"Care Connect" <${process.env.EMAIL_USER}>`,
      to: email,
      subject: subject,
      html: html,
    };

    const result = await transporter.sendMail(mailOptions);
    console.log(`✅ Request rejected email sent to ${email}`);
    return result;
  } catch (error) {
    console.error('💥 Error sending request rejected email:', error);
    throw error;
  }
};

// Send request submitted email
const sendRequestSubmittedEmail = async (email, data) => {
  try {
    const { requesterName, requestTitle, requestId } = data;
    const subject = '📝 Request Submitted Successfully';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #007bff;">Request Submitted! 📋</h2>
        <p>Dear ${requesterName},</p>
        <p>Your request "<strong>${requestTitle}</strong>" has been submitted successfully.</p>
        <p>Request ID: ${requestId}</p>
        <p>Our admin team will review it shortly. You'll receive an email once it's approved.</p>
        <p>Thank you for using Care Connect!</p>
      </div>
    `;
    
    const mailOptions = {
      from: `"Care Connect" <${process.env.EMAIL_USER}>`,
      to: email,
      subject: subject,
      html: html,
    };

    const result = await transporter.sendMail(mailOptions);
    console.log(`✅ Request submitted email sent to ${email}`);
    return result;
  } catch (error) {
    console.error('💥 Error sending request submitted email:', error);
    throw error;
  }
};

// Update module.exports (line 631)


module.exports = {
  sendEmail,
  sendDonationVerifiedEmail,
  sendDonationRejectedEmail,
  sendDonationSubmittedEmail,
  sendNewDonationNotificationEmail,
  sendRequestVerifiedEmail,      // ADD THIS
  sendRequestRejectedEmail,      // ADD THIS
  sendRequestSubmittedEmail,  
};
