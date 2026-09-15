"use client";

import { useEffect, useRef, useState } from "react";

const REPO_URL = "https://github.com/AgoraIO/skills";
const SHARE_IMAGE = "/share-card.jpg";

const X_TEXT =
	"Just built a real-time AI voice agent I can talk to in the browser — powered by @AgoraIO try it yourself: ";
const LINKEDIN_TEXT =
	"Just built a real-time AI voice agent you can talk to in the browser — powered by Agora. try it yourself: ";

function getXUrl() {
	return `https://twitter.com/intent/tweet?text=${encodeURIComponent(`${X_TEXT}\n\n${REPO_URL}`)}`;
}

function getLinkedInUrl() {
	return `https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(REPO_URL)}`;
}

type ShareButtonProps = {
	menuPlacement?: "top" | "bottom";
};

export function ShareButton({ menuPlacement = "bottom" }: ShareButtonProps) {
	const [open, setOpen] = useState(false);
	const [copied, setCopied] = useState(false);
	const ref = useRef<HTMLDivElement>(null);
	const menuPosition =
		menuPlacement === "top"
			? "bottom-full left-0 mb-2"
			: "right-0 top-full mt-2";

	useEffect(() => {
		function handleClick(e: MouseEvent) {
			if (ref.current && !ref.current.contains(e.target as Node)) {
				setOpen(false);
			}
		}
		if (open) document.addEventListener("mousedown", handleClick);
		return () => document.removeEventListener("mousedown", handleClick);
	}, [open]);

	function handleDownload() {
		const a = document.createElement("a");
		a.href = SHARE_IMAGE;
		a.download = "agora-voice-agent.jpg";
		a.click();
	}

	async function handleCopy() {
		try {
			// Convert to PNG for clipboard (clipboard API requires PNG)
			const img = new Image();
			img.src = SHARE_IMAGE;
			await new Promise((resolve) => {
				img.onload = resolve;
			});
			const canvas = document.createElement("canvas");
			canvas.width = img.width;
			canvas.height = img.height;
			const context = canvas.getContext("2d");
			if (!context) throw new Error("Could not create canvas context");
			context.drawImage(img, 0, 0);
			const pngBlob = await new Promise<Blob>((resolve, reject) => {
				canvas.toBlob((blob) => {
					if (blob) {
						resolve(blob);
					} else {
						reject(new Error("Could not convert share image"));
					}
				}, "image/png");
			});
			await navigator.clipboard.write([
				new ClipboardItem({ "image/png": pngBlob }),
			]);
		} catch {
			await navigator.clipboard.writeText(REPO_URL);
		}
		setCopied(true);
		setTimeout(() => setCopied(false), 2000);
	}

	function handleX() {
		window.open(getXUrl(), "_blank", "noopener");
	}

	async function handleLinkedIn() {
		// Copy text for LinkedIn post box, then open share URL
		await navigator.clipboard.writeText(`${LINKEDIN_TEXT}\n\n${REPO_URL}`);
		window.open(getLinkedInUrl(), "_blank", "noopener");
	}

	return (
		<div ref={ref} className="relative">
			<button
				type="button"
				onClick={() => setOpen(!open)}
				className="inline-flex items-center gap-2 rounded-full border border-[hsl(var(--border))] bg-gradient-to-r from-[hsl(194,100%,50%,0.1)] to-[hsl(194,100%,50%,0.05)] px-4 py-2 text-sm font-medium text-[hsl(var(--foreground))] backdrop-blur-sm transition-all hover:border-[hsl(var(--primary))] hover:shadow-md"
			>
				<span>✨</span>
				Share demo
				<svg
					aria-hidden="true"
					width="16"
					height="16"
					viewBox="0 0 24 24"
					fill="none"
					stroke="currentColor"
					strokeWidth="2"
					strokeLinecap="round"
					strokeLinejoin="round"
				>
					<circle cx="18" cy="5" r="3" />
					<circle cx="6" cy="12" r="3" />
					<circle cx="18" cy="19" r="3" />
					<line x1="8.59" y1="13.51" x2="15.42" y2="17.49" />
					<line x1="15.41" y1="6.51" x2="8.59" y2="10.49" />
				</svg>
			</button>

			{open && (
				<div
					className={`absolute z-50 w-[min(420px,calc(100vw_-_2rem))] rounded-2xl border border-[hsl(var(--border))] bg-[hsl(var(--card))] p-5 shadow-xl backdrop-blur-md ${menuPosition}`}
				>
					<div className="mb-3 flex items-center justify-between">
						<p className="text-xs font-semibold uppercase tracking-wider text-[hsl(var(--primary))]">
							Share your demo
						</p>
						<button
							type="button"
							onClick={() => setOpen(false)}
							className="text-[hsl(var(--muted-foreground))] hover:text-[hsl(var(--foreground))]"
							aria-label="Close"
						>
							✕
						</button>
					</div>

					{/* Share card image */}
					<div className="group relative mb-4 overflow-hidden rounded-xl border border-[hsl(var(--border))]">
						<img src={SHARE_IMAGE} alt="Share card" className="w-full" />
						<button
							type="button"
							onClick={handleDownload}
							className="absolute bottom-2 right-2 rounded-md bg-black/70 px-2.5 py-1 text-[11px] font-medium text-white opacity-0 transition-opacity group-hover:opacity-100"
						>
							↓ Save image
						</button>
					</div>

					{/* Action buttons */}
					<div className="flex gap-2">
						<button
							type="button"
							onClick={handleCopy}
							className="flex flex-1 items-center justify-center gap-1.5 rounded-lg border border-[hsl(var(--border))] bg-[hsl(var(--background))] px-3 py-2.5 text-xs font-medium text-[hsl(var(--foreground))] transition-colors hover:bg-[hsl(var(--secondary))]"
						>
							{copied ? "✓ Copied" : "📋 Copy image"}
						</button>
						<button
							type="button"
							onClick={handleX}
							className="flex flex-1 items-center justify-center gap-1.5 rounded-lg bg-black px-3 py-2.5 text-xs font-medium text-white transition-opacity hover:opacity-80"
						>
							𝕏 Post
						</button>
						<button
							type="button"
							onClick={handleLinkedIn}
							className="flex flex-1 items-center justify-center gap-1.5 rounded-lg bg-[#0A66C2] px-3 py-2.5 text-xs font-medium text-white transition-opacity hover:opacity-80"
						>
							in LinkedIn
						</button>
					</div>
					<p className="mt-2.5 text-center text-[10px] text-[hsl(var(--muted-foreground))]">
						Download the image and attach it to your post for best results.
					</p>
				</div>
			)}
		</div>
	);
}
