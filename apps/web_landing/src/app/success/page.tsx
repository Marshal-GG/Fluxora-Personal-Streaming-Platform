import Link from 'next/link';

export default function SuccessPage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-100 flex items-center justify-center p-6">
      <div className="max-w-md w-full bg-slate-900 border border-slate-800 rounded-2xl p-8 text-center space-y-6">
        <div className="w-16 h-16 bg-indigo-500/10 text-indigo-400 rounded-full flex items-center justify-center mx-auto">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>
        </div>
        
        <div className="space-y-2">
          <h1 className="text-2xl font-bold">Purchase Successful!</h1>
          <p className="text-slate-400">
            Thank you for supporting Fluxora. Your payment has been processed successfully.
          </p>
        </div>

        <div className="p-4 bg-slate-950/50 rounded-xl border border-slate-800 text-left">
          <h2 className="text-sm font-semibold text-slate-300 mb-2">What's next?</h2>
          <ol className="text-sm text-slate-400 space-y-2 list-decimal ml-4">
            <li>Check your email inbox for your <strong>License Key</strong>.</li>
            <li>Open the <strong>Fluxora Desktop Control Panel</strong>.</li>
            <li>Go to <strong>Settings &gt; License</strong> and paste your key.</li>
            <li>Enjoy your upgraded streaming experience!</li>
          </ol>
        </div>

        <div className="pt-4">
          <Link 
            href="/"
            className="inline-flex items-center justify-center px-6 py-3 rounded-lg bg-indigo-600 hover:bg-indigo-500 font-medium transition-colors w-full"
          >
            Return to Homepage
          </Link>
        </div>
        
        <p className="text-xs text-slate-500">
          Didn't receive an email? Check your spam folder or contact <a href="mailto:support@fluxora.dev" className="text-indigo-400 hover:underline">support@fluxora.dev</a>
        </p>
      </div>
    </main>
  );
}
