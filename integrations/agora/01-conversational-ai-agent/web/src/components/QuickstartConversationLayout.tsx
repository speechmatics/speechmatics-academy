"use client";

import Image from "next/image";
import type { ReactNode } from "react";

import { Button } from "@/components/ui/button";

type QuickstartConversationLayoutProps = {
	statusPanel: ReactNode;
	pipelineMetrics: ReactNode;
	transcriptPanel: ReactNode;
	visualizer: ReactNode;
	controls: ReactNode;
	onEndConversation: () => void;
};

export function QuickstartConversationLayout({
	statusPanel,
	pipelineMetrics,
	transcriptPanel,
	visualizer,
	controls,
	onEndConversation,
}: QuickstartConversationLayoutProps) {
	return (
		<div className="flex min-h-0 flex-1 flex-col text-left">
			<header className="flex shrink-0 flex-col gap-4 border-b border-border px-4 py-4 md:h-[76px] md:flex-row md:items-center md:justify-between md:px-6 md:py-0">
				<div className="flex min-w-0 items-center gap-3">
					<Image
						src="/agora-logo-mark.svg"
						alt="Agora"
						width={40}
						height={40}
						className="h-10 w-10 shrink-0 object-contain"
					/>
					<div className="flex min-w-0 flex-col justify-center gap-1">
						<span className="truncate text-lg font-semibold leading-none tracking-[-0.025em] text-foreground">
							Agora Conversational AI
						</span>
						{pipelineMetrics}
					</div>
				</div>

				<div className="flex items-center gap-2 md:pr-1">
					{statusPanel}
					<Button
						variant="destructive"
						size="sm"
						className="h-8 rounded-md border border-destructive bg-transparent px-3 text-xs font-medium text-destructive hover:bg-destructive/10"
						onClick={onEndConversation}
						aria-label="End conversation with AI agent"
						title="End conversation"
					>
						End Conversation
					</Button>
				</div>
			</header>

			<div className="flex min-h-0 w-full flex-1 flex-col gap-4 px-4 pb-4 pt-4 md:px-6 lg:flex-row lg:gap-0">
				<aside className="order-2 h-64 min-h-0 w-full shrink-0 lg:order-1 lg:h-full lg:w-[26rem]">
					{transcriptPanel}
				</aside>

				<main className="order-1 flex min-h-0 flex-1 flex-col lg:order-2 lg:border-l lg:border-border/80 lg:pl-6">
					<div className="flex min-h-0 flex-1 flex-col pb-2 pt-3 md:pb-6">
						<div className="flex min-h-0 flex-1 items-center justify-center">
							{visualizer}
						</div>
						<div className="shrink-0 pt-4">{controls}</div>
					</div>
				</main>
			</div>
		</div>
	);
}
