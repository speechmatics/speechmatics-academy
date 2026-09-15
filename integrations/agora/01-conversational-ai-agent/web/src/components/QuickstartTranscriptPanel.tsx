"use client";

import { useEffect, useMemo, useRef } from "react";

type TranscriptMessage = {
	turn_id?: string | number;
	uid: number;
	text?: string;
	createdAt?: number;
};

type QuickstartTranscriptPanelProps = {
	messageList: TranscriptMessage[];
	currentInProgressMessage: TranscriptMessage | null;
	agentUID: string;
};

function formatMessageTime(createdAt?: number) {
	if (!createdAt) return null;
	return new Intl.DateTimeFormat(undefined, {
		hour: "numeric",
		minute: "2-digit",
	}).format(new Date(createdAt));
}

export function QuickstartTranscriptPanel({
	messageList,
	currentInProgressMessage,
	agentUID,
}: QuickstartTranscriptPanelProps) {
	const scrollRef = useRef<HTMLDivElement>(null);
	const messages = useMemo(
		() =>
			currentInProgressMessage
				? [...messageList, currentInProgressMessage]
				: messageList,
		[currentInProgressMessage, messageList],
	);

	useEffect(() => {
		const node = scrollRef.current;
		if (!node) return;
		node.scrollTop = node.scrollHeight;
	});

	return (
		<section
			className="flex h-full min-h-0 w-full flex-col overflow-hidden rounded-2xl border border-border bg-card/20"
			aria-label="Transcription panel"
		>
			<div className="flex h-14 shrink-0 items-center justify-between border-b border-border px-4">
				<div>
					<h2 className="text-sm font-semibold text-foreground">Transcript</h2>
					<p className="text-xs text-muted-foreground">Live voice turns</p>
				</div>
			</div>

			<div
				ref={scrollRef}
				className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto px-4 py-4"
			>
				{messages.length === 0 ? (
					<div className="flex h-full items-center justify-center text-center text-sm text-muted-foreground">
						Start speaking to see the live transcript here.
					</div>
				) : (
					messages.map((message, index) => {
						const isAgent = String(message.uid) === agentUID;
						const label = isAgent ? "Agent" : "You";
						const text = message.text?.trim();
						const time = formatMessageTime(message.createdAt);

						return (
							<article
								key={`${message.turn_id ?? message.uid}-${index}`}
								className={`flex flex-col ${isAgent ? "items-start" : "items-end"}`}
							>
								<div className="mb-1 flex items-center gap-2 px-1 text-xs font-semibold text-muted-foreground">
									<span>{label}</span>
									{time ? <span className="font-normal">{time}</span> : null}
								</div>
								<div
									className={`max-w-full whitespace-pre-wrap rounded-xl border px-3 py-2 text-sm leading-6 ${
										isAgent
											? "border-[#2f2f2f] bg-[#212121] text-[#e7e7e7]"
											: "border-[#d7d7d7] bg-[#fdfcfb] text-black"
									}`}
								>
									{text || "..."}
								</div>
							</article>
						);
					})
				)}
			</div>
		</section>
	);
}
